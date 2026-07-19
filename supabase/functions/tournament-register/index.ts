import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { debitCurrency, creditCurrency } from '../_shared/currency.ts';
import { getEconomyConfig } from '../_shared/rewards.ts';
import { startTournament } from '../_shared/tournament_report.ts';

interface RegisterRequest { tournament_id: string; }

const TIER_RANK: Record<string, number> = { free: 0, pro: 1, max: 2 };

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: RegisterRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400);

    // ── Load tournament ────────────────────────────────────────────────────
    const { data: t } = await admin
      .from('tournaments')
      .select('id, status, max_participants, current_participants, entry_fee_coins, entry_fee_gems, min_subscription_tier, settings')
      .eq('id', body.tournament_id)
      .single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if (t.status !== 'registration') return errorResponse('Registration is closed', 409, 'REGISTRATION_CLOSED');
    if (t.current_participants >= t.max_participants) return errorResponse('Tournament is full', 409, 'TOURNAMENT_FULL');

    // ── Load profile: tier + account_type + balances ───────────────────────
    const { data: profile } = await admin
      .from('profiles')
      .select('subscription_tier, account_type, coins, gems')
      .eq('id', user.id)
      .single();
    if (!profile) return errorResponse('Profile not found', 404);

    // ── Subscription-tier gate ─────────────────────────────────────────────
    if ((TIER_RANK[profile.subscription_tier] ?? 0) < (TIER_RANK[t.min_subscription_tier] ?? 0)) {
      return errorResponse(`Requires ${t.min_subscription_tier} subscription`, 403, 'TIER_REQUIRED');
    }

    // ── Gem entry requires a registered account (guests = coin economy) ────
    if (t.entry_fee_gems > 0 && profile.account_type !== 'registered') {
      return errorResponse('Create an account to enter gem tournaments', 403, 'REGISTERED_REQUIRED');
    }

    // ── Active-tournament concurrency cap ──────────────────────────────────
    const config = await getEconomyConfig(admin);
    const { data: activeRows } = await admin
      .from('tournament_participants')
      .select('tournament_id, tournaments!inner(status)')
      .eq('user_id', user.id)
      .in('tournaments.status', ['registration', 'starting', 'in_progress']);
    if ((activeRows?.length ?? 0) >= config.active_tournament_cap) {
      return errorResponse('Too many active tournaments', 429, 'TOO_MANY_ACTIVE_TOURNAMENTS');
    }

    // ── Debit entry fee (coins then gems), with compensating rollback ──────
    let coinsAfter: number | null = null;
    let gemsAfter: number | null = null;
    if (t.entry_fee_coins > 0) {
      try {
        const r = await debitCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_entry', t.id);
        coinsAfter = r.balance_after;
      } catch {
        return errorResponse('Insufficient coins', 402, 'INSUFFICIENT_FUNDS');
      }
    }
    if (t.entry_fee_gems > 0) {
      try {
        const r = await debitCurrency(admin, user.id, 'gems', t.entry_fee_gems, 'tournament_entry', t.id);
        gemsAfter = r.balance_after;
      } catch {
        // Roll back the coins debit if gems fail.
        if (t.entry_fee_coins > 0) {
          await creditCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_refund', t.id);
        }
        return errorResponse('Insufficient gems', 402, 'INSUFFICIENT_FUNDS');
      }
    }

    // ── Insert participant + ledger (unique guards prevent double entry) ───
    const { error: partErr } = await admin
      .from('tournament_participants')
      .insert({ tournament_id: t.id, user_id: user.id });
    if (partErr) {
      // Refund on duplicate / failure.
      if (t.entry_fee_coins > 0) await creditCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_refund', t.id);
      if (t.entry_fee_gems > 0) await creditCurrency(admin, user.id, 'gems', t.entry_fee_gems, 'tournament_refund', t.id);
      if (partErr.code === '23505') return errorResponse('Already registered', 409, 'ALREADY_REGISTERED');
      throw partErr;
    }

    await admin.from('tournament_entry_ledger').insert({
      tournament_id: t.id, user_id: user.id,
      coins_paid: t.entry_fee_coins, gems_paid: t.entry_fee_gems,
    });

    // ── Post-insert capacity re-check (lost-race rollback) ─────────────────
    const { data: t2 } = await admin
      .from('tournaments').select('current_participants, max_participants').eq('id', t.id).single();
    if (t2 && t2.current_participants > t2.max_participants) {
      await admin.from('tournament_participants').delete().eq('tournament_id', t.id).eq('user_id', user.id);
      await admin.from('tournament_entry_ledger').update({ refunded: true }).eq('tournament_id', t.id).eq('user_id', user.id);
      if (t.entry_fee_coins > 0) await creditCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_refund', t.id);
      if (t.entry_fee_gems > 0) await creditCurrency(admin, user.id, 'gems', t.entry_fee_gems, 'tournament_refund', t.id);
      return errorResponse('Tournament is full', 409, 'TOURNAMENT_FULL');
    }

    // ── Auto-start when the last seat fills ────────────────────────────────
    // There is no scheduler yet (see prompts/25 §T1): without this, a full
    // tournament sits in 'registration' until an admin force-starts it.
    // Opt out per-tournament via settings.auto_start_when_full = false.
    // startTournament is race-safe here: a concurrent start loses the status
    // gate ('registration'/'starting' only) and returns BAD_STATUS, which we
    // deliberately ignore.
    let started = false;
    const autoStart =
      (t.settings as { auto_start_when_full?: boolean } | null)?.auto_start_when_full !== false;
    if (autoStart && t2 && t2.current_participants >= t2.max_participants) {
      try {
        const r = await startTournament(admin, t.id);
        started = r.status === 'started';
      } catch (e) {
        // Registration itself succeeded — never fail the request over this.
        console.error('auto-start after fill failed:', e);
      }
    }

    return jsonResponse({ ok: true, coins_balance: coinsAfter, gems_balance: gemsAfter, started });
  } catch (error) {
    console.error('tournament-register error:', error);
    return errorResponse('Internal server error', 500);
  }
});
