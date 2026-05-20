import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency } from '../_shared/currency.ts';

interface GrantSeasonRewardRequest {
  season_id: string;
  level: number;
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

    const body: GrantSeasonRewardRequest = await req.json();
    if (!body.season_id || body.level == null) {
      return errorResponse('season_id and level are required', 400);
    }

    // ── Fetch season ──────────────────────────────────────────────────────
    const { data: season } = await admin
      .from('seasons')
      .select('*')
      .eq('id', body.season_id)
      .single();

    if (!season) return errorResponse('Season not found', 404);
    if (!season.is_active) return errorResponse('Season is not active', 400);

    // ── Fetch user progress ───────────────────────────────────────────────
    const { data: progress } = await admin
      .from('user_season_progress')
      .select('*')
      .eq('user_id', user.id)
      .eq('season_id', body.season_id)
      .maybeSingle();

    if (!progress) {
      return errorResponse('No season progress found', 404, 'NO_PROGRESS');
    }

    if (progress.level < body.level) {
      return errorResponse(
        `Not at level ${body.level} yet (current: ${progress.level})`,
        400,
        'LEVEL_NOT_REACHED',
      );
    }

    // ── Get reward definition from season metadata ────────────────────────
    const rewards = (season.metadata?.rewards as Record<string, unknown>[]) || [];
    const levelReward = rewards.find(
      (r: Record<string, unknown>) => r.level === body.level,
    ) as Record<string, unknown> | undefined;

    if (!levelReward) {
      return errorResponse('No reward defined for this level', 400, 'NO_REWARD');
    }

    // ── Check if already claimed ──────────────────────────────────────────
    const { data: existingClaim } = await admin
      .from('currency_transactions')
      .select('id')
      .eq('user_id', user.id)
      .eq('reason', `season_reward_${body.season_id}_${body.level}`)
      .maybeSingle();

    if (existingClaim) {
      return errorResponse('Reward already claimed', 400, 'ALREADY_CLAIMED');
    }

    // ── Determine track (free vs premium) ─────────────────────────────────
    const hasPremium = progress.premium_purchased_at != null;
    const track = hasPremium ? 'premium' : 'free';

    const rewardData = (levelReward[track] || levelReward.free) as Record<string, unknown>;
    if (!rewardData) {
      return errorResponse('No reward available on your track', 400);
    }

    // ── Grant rewards ─────────────────────────────────────────────────────
    const reason = `season_reward_${body.season_id}_${body.level}`;
    const granted: Record<string, unknown> = {};

    if (rewardData.coins && (rewardData.coins as number) > 0) {
      const r = await creditCurrency(
        admin, user.id, 'coins', rewardData.coins as number, reason,
      );
      granted.coins = rewardData.coins;
      granted.coins_balance = r.balance_after;
    }

    if (rewardData.gems && (rewardData.gems as number) > 0) {
      const r = await creditCurrency(
        admin, user.id, 'gems', rewardData.gems as number, reason,
      );
      granted.gems = rewardData.gems;
      granted.gems_balance = r.balance_after;
    }

    // Grant skin/cosmetic if specified
    if (rewardData.skin_id) {
      await admin.from('user_skins').insert({
        user_id: user.id,
        skin_id: rewardData.skin_id,
      });
      granted.skin_id = rewardData.skin_id;
    }

    return jsonResponse({
      level: body.level,
      track,
      reward: granted,
    });
  } catch (error) {
    console.error('Grant season reward error:', error);
    return errorResponse('Internal server error', 500);
  }
});
