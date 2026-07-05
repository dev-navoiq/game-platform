import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency } from '../_shared/currency.ts';
import { isGuest } from '../_shared/identity.ts';

interface RecordReferralRequest {
  referral_code: string;
}

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: RecordReferralRequest = await req.json();
    if (!body.referral_code) {
      return errorResponse('referral_code is required', 400);
    }

    // ── Referee must be registered (guests can't earn referral rewards) ────
    if (await isGuest(admin, user.id)) {
      return errorResponse('Create an account to use a referral code', 403, 'REGISTERED_REQUIRED');
    }

    // ── Look up referrer ──────────────────────────────────────────────────
    const { data: referrer } = await admin
      .from('profiles')
      .select('id, username, referral_code')
      .eq('referral_code', body.referral_code.toUpperCase())
      .maybeSingle();

    if (!referrer) {
      return errorResponse('Invalid referral code', 404, 'INVALID_CODE');
    }

    // ── Self-referral check ───────────────────────────────────────────────
    if (referrer.id === user.id) {
      return errorResponse('Cannot refer yourself', 400, 'SELF_REFERRAL');
    }

    // ── Check user not already referred ───────────────────────────────────
    const { data: existingRef } = await admin
      .from('referrals')
      .select('id')
      .eq('referee_id', user.id)
      .maybeSingle();

    if (existingRef) {
      return errorResponse('Already used a referral code', 400, 'ALREADY_REFERRED');
    }

    // ── Anti-abuse: max 20 referrals/month ────────────────────────────────
    const monthStart = new Date();
    monthStart.setUTCDate(1);
    monthStart.setUTCHours(0, 0, 0, 0);

    const { count } = await admin
      .from('referrals')
      .select('*', { count: 'exact', head: true })
      .eq('referrer_id', referrer.id)
      .gte('created_at', monthStart.toISOString());

    if ((count || 0) >= 20) {
      return errorResponse('Referrer has reached monthly limit', 400, 'REFERRER_LIMIT');
    }

    // ── Create referral record ────────────────────────────────────────────
    const { data: referral, error: refErr } = await admin
      .from('referrals')
      .insert({
        referrer_id: referrer.id,
        referee_id: user.id,
        code_used: body.referral_code.toUpperCase(),
        tier_reached: 1,
        rewarded_at: [new Date().toISOString()],
      })
      .select()
      .single();

    if (refErr) {
      if (refErr.code === '23505') {
        // Unique constraint violation
        return errorResponse('Already used a referral code', 400, 'ALREADY_REFERRED');
      }
      throw refErr;
    }

    // ── Update referee's referred_by ──────────────────────────────────────
    await admin
      .from('profiles')
      .update({ referred_by: referrer.id })
      .eq('id', user.id);

    // ── Tier 1 rewards: Install ───────────────────────────────────────────
    // Referrer gets 100 coins
    await creditCurrency(admin, referrer.id, 'coins', 100, 'referral_reward_tier1', referral.id);
    // Referee gets 200 coins
    await creditCurrency(admin, user.id, 'coins', 200, 'referral_bonus_tier1', referral.id);

    return jsonResponse({
      referral_id: referral.id,
      referrer_username: referrer.username,
      coins_awarded: 200,
      message: 'Referral recorded! You received 200 coins.',
    });
  } catch (error) {
    console.error('Record referral error:', error);
    return errorResponse('Internal server error', 500);
  }
});
