import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { debitCurrency, creditCurrency } from '../_shared/currency.ts';
import { getEconomyConfig } from '../_shared/rewards.ts';
import { startTournament } from '../_shared/tournament_report.ts';

// Registration, including team tournaments (team_size = 2):
//   { tournament_id }                    — individual, or solo entry when the
//                                          tournament allows solo pairing
//   { tournament_id, create_team: true } — register and open a new team
//   { tournament_id, join_team: <id> }   — register into an open (1-member) team
// Fees are per player in all modes.
interface RegisterRequest {
  tournament_id: string;
  create_team?: boolean;
  join_team?: string;
}

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
      .select('id, status, max_participants, current_participants, entry_fee_coins, entry_fee_gems, min_subscription_tier, settings, team_size, allow_solo_pairing, check_in_minutes')
      .eq('id', body.tournament_id)
      .single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if (t.status !== 'registration') return errorResponse('Registration is closed', 409, 'REGISTRATION_CLOSED');
    if (t.current_participants >= t.max_participants) return errorResponse('Tournament is full', 409, 'TOURNAMENT_FULL');

    // ── Team-mode pre-checks (before any money moves) ──────────────────────
    const isTeamTournament = t.team_size === 2;
    if (!isTeamTournament && (body.create_team || body.join_team)) {
      return errorResponse('This is an individual tournament', 400, 'NOT_TEAM_TOURNAMENT');
    }
    if (isTeamTournament) {
      if (body.join_team) {
        const { data: team } = await admin
          .from('tournament_teams')
          .select('id')
          .eq('id', body.join_team)
          .eq('tournament_id', t.id)
          .maybeSingle();
        if (!team) return errorResponse('Team not found', 404, 'TEAM_NOT_FOUND');
        const { count } = await admin
          .from('tournament_participants')
          .select('*', { count: 'exact', head: true })
          .eq('team_id', body.join_team);
        if ((count ?? 0) >= t.team_size) return errorResponse('Team is full', 409, 'TEAM_FULL');
      } else if (!body.create_team && !t.allow_solo_pairing) {
        return errorResponse(
          'This tournament requires teams: create a team or join one',
          400, 'TEAM_REQUIRED',
        );
      }
    }

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

    // ── Claim the seat FIRST — idempotency guard before any money moves ────
    // The unique (tournament_id, user_id) constraint turns a double-submitted
    // register (double-tap / client retry) into a clean ALREADY_REGISTERED
    // exit with zero debits, instead of debiting twice and compensating later.
    const { error: partErr } = await admin
      .from('tournament_participants')
      .insert({ tournament_id: t.id, user_id: user.id });
    if (partErr) {
      if (partErr.code === '23505') return errorResponse('Already registered', 409, 'ALREADY_REGISTERED');
      throw partErr;
    }
    const releaseSeat = () =>
      admin.from('tournament_participants').delete().eq('tournament_id', t.id).eq('user_id', user.id);

    // ── Debit entry fee (coins then gems); release the seat on failure ─────
    let coinsAfter: number | null = null;
    let gemsAfter: number | null = null;
    if (t.entry_fee_coins > 0) {
      try {
        const r = await debitCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_entry', t.id);
        coinsAfter = r.balance_after;
      } catch {
        await releaseSeat();
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
        await releaseSeat();
        return errorResponse('Insufficient gems', 402, 'INSUFFICIENT_FUNDS');
      }
    }

    // Shared rollback for post-debit failures.
    const rollbackEntry = async () => {
      await admin.from('tournament_participants').delete().eq('tournament_id', t.id).eq('user_id', user.id);
      await admin.from('tournament_entry_ledger').update({ refunded: true }).eq('tournament_id', t.id).eq('user_id', user.id);
      if (t.entry_fee_coins > 0) await creditCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_refund', t.id);
      if (t.entry_fee_gems > 0) await creditCurrency(admin, user.id, 'gems', t.entry_fee_gems, 'tournament_refund', t.id);
    };

    // ── Ledger: UPSERT, and check the result ───────────────────────────────
    // A row left behind by a previous withdraw/cancel (refunded=true) must be
    // reactivated with the new payment. The old blind insert silently hit the
    // unique constraint, left the stale refunded=true row in place, and the
    // next withdrawal then paid nothing — the fee was lost permanently.
    const { error: ledgerErr } = await admin.from('tournament_entry_ledger').upsert(
      {
        tournament_id: t.id, user_id: user.id,
        coins_paid: t.entry_fee_coins, gems_paid: t.entry_fee_gems,
        refunded: false, paid_out: false,
      },
      { onConflict: 'tournament_id,user_id' },
    );
    if (ledgerErr) {
      // Without a live ledger row no refund can ever be paid — undo everything.
      if (t.entry_fee_coins > 0) await creditCurrency(admin, user.id, 'coins', t.entry_fee_coins, 'tournament_refund', t.id);
      if (t.entry_fee_gems > 0) await creditCurrency(admin, user.id, 'gems', t.entry_fee_gems, 'tournament_refund', t.id);
      await releaseSeat();
      throw ledgerErr;
    }

    // ── Team linkage ───────────────────────────────────────────────────────
    let teamId: string | null = null;
    if (isTeamTournament && body.join_team) {
      await admin.from('tournament_participants')
        .update({ team_id: body.join_team })
        .eq('tournament_id', t.id).eq('user_id', user.id);
      // Lost-race re-check: if a concurrent join overfilled the team, back out.
      const { count } = await admin
        .from('tournament_participants')
        .select('*', { count: 'exact', head: true })
        .eq('team_id', body.join_team);
      if ((count ?? 0) > t.team_size) {
        await rollbackEntry();
        return errorResponse('Team is full', 409, 'TEAM_FULL');
      }
      teamId = body.join_team;
    } else if (isTeamTournament && body.create_team) {
      const { data: team, error: teamErr } = await admin
        .from('tournament_teams')
        .insert({ tournament_id: t.id, captain_id: user.id })
        .select('id')
        .single();
      if (teamErr || !team) {
        await rollbackEntry();
        return errorResponse('Could not create team', 409, 'TEAM_CREATE_FAILED');
      }
      await admin.from('tournament_participants')
        .update({ team_id: team.id })
        .eq('tournament_id', t.id).eq('user_id', user.id);
      teamId = team.id;
    }
    // else: solo entry (allow_solo_pairing) — paired at start time.

    // ── Post-insert capacity re-check (lost-race rollback) ─────────────────
    const { data: t2 } = await admin
      .from('tournaments').select('current_participants, max_participants').eq('id', t.id).single();
    if (t2 && t2.current_participants > t2.max_participants) {
      // Note: rollbackEntry deletes the participant; team_id FK is ON DELETE
      // SET NULL so an opened team simply becomes empty and is ignored/cleaned
      // at start.
      await rollbackEntry();
      return errorResponse('Tournament is full', 409, 'TOURNAMENT_FULL');
    }

    // ── Auto-start when the last seat fills ────────────────────────────────
    // There is no start_time wait needed for a full house (see prompts/25 §T1
    // for the scheduler that covers the not-full case). Opt out per-tournament
    // via settings.auto_start_when_full = false. startTournament is race-safe
    // here: a concurrent start loses the status gate and returns BAD_STATUS.
    // Team tournaments: startTournament pairs solos / drops incomplete teams.
    let started = false;
    // Check-in tournaments are scheduled events: filling the roster must NOT
    // start them early, or the check-in window would never happen (§T6).
    const autoStart =
      (t.settings as { auto_start_when_full?: boolean } | null)?.auto_start_when_full !== false &&
      (t.check_in_minutes ?? 0) === 0;
    if (autoStart && t2 && t2.current_participants >= t2.max_participants) {
      try {
        const r = await startTournament(admin, t.id);
        started = r.status === 'started';
      } catch (e) {
        // Registration itself succeeded — never fail the request over this.
        console.error('auto-start after fill failed:', e);
      }
    }

    return jsonResponse({
      ok: true,
      coins_balance: coinsAfter,
      gems_balance: gemsAfter,
      started,
      team_id: teamId,
    });
  } catch (error) {
    console.error('tournament-register error:', error);
    return errorResponse('Internal server error', 500);
  }
});
