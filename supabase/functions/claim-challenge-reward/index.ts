import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency, grantXp } from '../_shared/currency.ts';

interface ClaimChallengeRequest {
  challenge_id: string;
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

    const body: ClaimChallengeRequest = await req.json();
    if (!body.challenge_id) return errorResponse('challenge_id is required', 400);

    // ── Fetch user_challenge with challenge details ───────────────────────
    const { data: uc, error: ucErr } = await admin
      .from('user_challenges')
      .select('*, challenges(*)')
      .eq('user_id', user.id)
      .eq('challenge_id', body.challenge_id)
      .maybeSingle();

    if (ucErr || !uc) {
      return errorResponse('Challenge not found', 404, 'CHALLENGE_NOT_FOUND');
    }

    if (uc.reward_claimed) {
      return errorResponse('Reward already claimed', 400, 'ALREADY_CLAIMED');
    }

    if (!uc.completed_at) {
      return errorResponse('Challenge not completed yet', 400, 'NOT_COMPLETED');
    }

    const challenge = uc.challenges;

    // ── Award rewards ─────────────────────────────────────────────────────
    let coinsBalance = 0;
    let gemsBalance = 0;

    if (challenge.reward_coins > 0) {
      const r = await creditCurrency(
        admin, user.id, 'coins', challenge.reward_coins,
        'challenge_reward', body.challenge_id,
      );
      coinsBalance = r.balance_after;
    }

    if (challenge.reward_gems > 0) {
      const r = await creditCurrency(
        admin, user.id, 'gems', challenge.reward_gems,
        'challenge_reward', body.challenge_id,
      );
      gemsBalance = r.balance_after;
    }

    // ── Grant XP ──────────────────────────────────────────────────────────
    let xpResult = null;
    if (challenge.reward_xp > 0) {
      xpResult = await grantXp(admin, user.id, challenge.reward_xp);
    }

    // ── Mark as claimed ───────────────────────────────────────────────────
    await admin
      .from('user_challenges')
      .update({ reward_claimed: true })
      .eq('id', uc.id);

    // ── Update season progress if active season ───────────────────────────
    if (challenge.reward_xp > 0) {
      await addSeasonXp(admin, user.id, challenge.reward_xp);
    }

    return jsonResponse({
      coins_awarded: challenge.reward_coins,
      gems_awarded: challenge.reward_gems,
      xp_awarded: challenge.reward_xp,
      coins_balance: coinsBalance,
      gems_balance: gemsBalance,
      xp_result: xpResult,
    });
  } catch (error) {
    console.error('Claim challenge reward error:', error);
    return errorResponse('Internal server error', 500);
  }
});

async function addSeasonXp(
  admin: ReturnType<typeof getSupabaseAdmin>,
  userId: string,
  xp: number,
): Promise<void> {
  // Find active season
  const { data: season } = await admin
    .from('seasons')
    .select('id, max_level')
    .eq('is_active', true)
    .maybeSingle();

  if (!season) return;

  // Upsert season progress
  const { data: progress } = await admin
    .from('user_season_progress')
    .select('*')
    .eq('user_id', userId)
    .eq('season_id', season.id)
    .maybeSingle();

  if (!progress) {
    await admin.from('user_season_progress').insert({
      user_id: userId,
      season_id: season.id,
      xp,
      level: 0,
    });
    return;
  }

  let newXp = progress.xp + xp;
  let newLevel = progress.level;
  const xpPerLevel = 1000;

  while (newXp >= xpPerLevel && newLevel < season.max_level) {
    newXp -= xpPerLevel;
    newLevel++;
  }

  await admin
    .from('user_season_progress')
    .update({ xp: newXp, level: newLevel })
    .eq('id', progress.id);
}
