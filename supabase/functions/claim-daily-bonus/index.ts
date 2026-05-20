import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency, grantXp } from '../_shared/currency.ts';

// Daily login streak rewards (from product strategy Part 3.3)
const STREAK_REWARDS: Record<number, { coins: number; gems: number }> = {
  1: { coins: 15, gems: 0 },
  2: { coins: 20, gems: 0 },
  3: { coins: 25, gems: 0 },
  4: { coins: 30, gems: 0 },
  5: { coins: 40, gems: 0 },
  6: { coins: 50, gems: 0 },
  7: { coins: 60, gems: 10 },
  14: { coins: 80, gems: 20 },
  30: { coins: 100, gems: 50 },
};

function getRewardForDay(day: number): { coins: number; gems: number } {
  if (STREAK_REWARDS[day]) return STREAK_REWARDS[day];
  // Default: interpolated 15 + (day-1)*2 capped at 60
  const coins = Math.min(15 + (day - 1) * 2, 60);
  return { coins, gems: 0 };
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

    // ── Check last claim ──────────────────────────────────────────────────
    const { data: lastClaim } = await admin
      .from('currency_transactions')
      .select('created_at')
      .eq('user_id', user.id)
      .eq('reason', 'daily_bonus')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    const today = new Date();
    const todayStr = today.toISOString().split('T')[0];

    if (lastClaim) {
      const lastClaimDate = lastClaim.created_at.split('T')[0];
      if (lastClaimDate === todayStr) {
        return errorResponse('Already claimed today', 400, 'ALREADY_CLAIMED');
      }
    }

    // ── Calculate streak ──────────────────────────────────────────────────
    const { data: profile } = await admin
      .from('profiles')
      .select('current_activity')
      .eq('id', user.id)
      .single();

    const activity = (profile?.current_activity as Record<string, unknown>) || {};
    let streak = 1;

    if (lastClaim) {
      const lastDate = new Date(lastClaim.created_at);
      const yesterday = new Date(today);
      yesterday.setUTCDate(yesterday.getUTCDate() - 1);
      const yesterdayStr = yesterday.toISOString().split('T')[0];
      const lastStr = lastDate.toISOString().split('T')[0];

      if (lastStr === yesterdayStr) {
        // Consecutive day
        streak = ((activity.daily_streak as number) || 0) + 1;
      }
      // else streak resets to 1
    }

    // Cycle after day 30
    const effectiveDay = streak > 30 ? ((streak - 1) % 30) + 1 : streak;
    const reward = getRewardForDay(effectiveDay);

    // ── Grant rewards ─────────────────────────────────────────────────────
    const coinResult = await creditCurrency(
      admin, user.id, 'coins', reward.coins, 'daily_bonus',
    );

    let gemResult = null;
    if (reward.gems > 0) {
      gemResult = await creditCurrency(
        admin, user.id, 'gems', reward.gems, 'daily_bonus',
      );
    }

    // ── Update streak in profile activity ─────────────────────────────────
    await admin
      .from('profiles')
      .update({
        current_activity: {
          ...activity,
          daily_streak: streak,
          last_daily_claim: todayStr,
        },
      })
      .eq('id', user.id);

    // ── Grant XP for 7-day streak ─────────────────────────────────────────
    let xpResult = null;
    if (streak > 0 && streak % 7 === 0) {
      xpResult = await grantXp(admin, user.id, 300);
    }

    // ── Preview next day's reward ─────────────────────────────────────────
    const nextDay = streak + 1;
    const nextEffective = nextDay > 30 ? ((nextDay - 1) % 30) + 1 : nextDay;
    const nextReward = getRewardForDay(nextEffective);

    return jsonResponse({
      coins_awarded: reward.coins,
      gems_awarded: reward.gems,
      streak_day: streak,
      coins_balance: coinResult.balance_after,
      gems_balance: gemResult?.balance_after,
      xp_result: xpResult,
      next_reward: nextReward,
    });
  } catch (error) {
    console.error('Claim daily bonus error:', error);
    return errorResponse('Internal server error', 500);
  }
});
