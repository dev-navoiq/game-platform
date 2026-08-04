import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { creditCurrency, grantXp, addSeasonXp } from './currency.ts';
import { computeOutcomes, PlayerOutcome } from './game_outcome.ts';

export interface EconomyConfig {
  game_end_coins_win: number;
  game_end_coins_loss: number;
  game_end_xp_win: number;
  game_end_xp_loss: number;
  first_win_of_day_bonus: number;
  daily_coin_earn_cap: number;
  tier_earn_multiplier: Record<string, number>;
  welcome_gem_grant: number;
  rake_percent_default: number;
  active_tournament_cap: number;
}

/** Read the single-row economy_config. Not cached — one cheap indexed read. */
export async function getEconomyConfig(admin: SupabaseClient): Promise<EconomyConfig> {
  const { data, error } = await admin
    .from('economy_config')
    .select('*')
    .eq('id', 1)
    .single();
  if (error || !data) throw new Error(`economy_config missing: ${error?.message}`);
  return data as EconomyConfig;
}

interface DailyEarnState {
  date: string;
  coins_earned_today: number;
  first_win_claimed: boolean;
}

/** What was actually granted to one player — persisted to recent_games so
 *  the game-over dialog can show real numbers (#54). */
interface RewardReceipt {
  coins: number;
  xp: number;
  firstWinBonus: boolean;
  dailyCapHit: boolean;
}

function todayUtc(): string {
  return new Date().toISOString().split('T')[0];
}

/**
 * Grant coins + XP (global + season) to the human players of a finished game.
 * Exactly-once per room (guarded by game_reward_grants), bot-aware (only
 * room_players receive rewards), and config-driven. Gems are never granted at
 * game end. Also records per-player history via record_game_completion.
 *
 * Safe to call unconditionally from the game-end path: a second call for the
 * same room is a no-op.
 */
export async function grantGameEndRewards(
  admin: SupabaseClient,
  roomId: string,
  gameType: string,
  state: Record<string, unknown>,
): Promise<void> {
  // ── Exactly-once guard ──────────────────────────────────────────────────
  const { error: guardErr } = await admin
    .from('game_reward_grants')
    .insert({ room_id: roomId });
  if (guardErr) return; // unique_violation (already granted) or FK issue → no-op

  const outcomes = computeOutcomes(gameType, state);
  if (!outcomes.length) return; // unsupported game type / no end state

  // ── Restrict to human players (bots live only in game_rooms.config.bots) ──
  const { data: roomPlayers } = await admin
    .from('room_players')
    .select('user_id')
    .eq('room_id', roomId);
  const humanIds = new Set((roomPlayers ?? []).map((p) => p.user_id as string));
  const humanOutcomes = outcomes.filter((o) => humanIds.has(o.user_id));
  if (!humanOutcomes.length) return;

  const config = await getEconomyConfig(admin);
  const today = todayUtc();

  const receipts = new Map<string, RewardReceipt>();
  for (const o of humanOutcomes) {
    const receipt = await grantOne(admin, roomId, o, config, today);
    if (receipt) receipts.set(o.user_id, receipt);

    // ── Update leaderboard (Story #52) ──────────────────────────────────────
    const ratingChange = o.result === 'win' ? 25 : (o.result === 'loss' ? -15 : 0);
    try {
      await updateLeaderboard(admin, o.user_id, gameType, o.result, ratingChange);
    } catch (e) {
      console.error('updateLeaderboard failed', e);
    }
  }

  // ── Record match history + reward receipt (humans only) ─────────────────
  try {
    await admin.rpc('record_game_completion', {
      p_room_id: roomId,
      p_game_type: gameType,
      p_results: humanOutcomes.map((o) => ({
        user_id: o.user_id,
        result: o.result,
        position: o.position,
        points: o.points,
        elo_change: 0,
        coins_earned: receipts.get(o.user_id)?.coins ?? 0,
        xp_earned: receipts.get(o.user_id)?.xp ?? 0,
        gems_earned: 0, // never granted at game end by design
        first_win_bonus: receipts.get(o.user_id)?.firstWinBonus ?? false,
        daily_cap_hit: receipts.get(o.user_id)?.dailyCapHit ?? false,
      })),
    });
  } catch (e) {
    console.error('record_game_completion failed', e);
  }
}

async function grantOne(
  admin: SupabaseClient,
  roomId: string,
  o: PlayerOutcome,
  config: EconomyConfig,
  today: string,
): Promise<RewardReceipt | null> {
  const { data: profile } = await admin
    .from('profiles')
    .select('subscription_tier, daily_earn_state')
    .eq('id', o.user_id)
    .single();
  if (!profile) return null;

  const tier = (profile.subscription_tier as string) ?? 'free';
  const multiplier = config.tier_earn_multiplier[tier] ?? 1.0;

  // ── Daily earn accounting (reset per UTC day) ───────────────────────────
  let daily = profile.daily_earn_state as DailyEarnState | null;
  if (!daily || daily.date !== today) {
    daily = { date: today, coins_earned_today: 0, first_win_claimed: false };
  }

  const isWin = o.result === 'win';
  const base = isWin ? config.game_end_coins_win : config.game_end_coins_loss;
  const firstWin = isWin && !daily.first_win_claimed;
  const rawCoins = base + (firstWin ? config.first_win_of_day_bonus : 0);
  const scaledCoins = Math.round(rawCoins * multiplier);

  // ── Apply daily cap ─────────────────────────────────────────────────────
  const remaining = Math.max(0, config.daily_coin_earn_cap - daily.coins_earned_today);
  const grantCoins = Math.min(scaledCoins, remaining);

  if (firstWin) daily.first_win_claimed = true;
  daily.coins_earned_today += grantCoins;

  await admin
    .from('profiles')
    .update({ daily_earn_state: daily })
    .eq('id', o.user_id);

  // Single coins credit per (user, room) — satisfies uq_currency_game_reward.
  if (grantCoins > 0) {
    await creditCurrency(admin, o.user_id, 'coins', grantCoins, 'game_reward', roomId);
  }

  // ── XP: global + active season ──────────────────────────────────────────
  const xp = isWin ? config.game_end_xp_win : config.game_end_xp_loss;
  if (xp > 0) {
    await grantXp(admin, o.user_id, xp);
    await addSeasonXp(admin, o.user_id, xp);
  }

  return {
    coins: grantCoins,
    xp,
    firstWinBonus: firstWin,
    dailyCapHit: grantCoins < scaledCoins,
  };
}

/**
 * Update player's leaderboard entry for a specific game type.
 * Creates new entry if first game, otherwise updates existing stats.
 * Uses simple fixed-point rating system: +25 win, -15 loss, 0 draw.
 */
async function updateLeaderboard(
  admin: SupabaseClient,
  userId: string,
  gameType: string,
  result: 'win' | 'loss' | 'draw',
  ratingChange: number,
): Promise<void> {
  const { data: existing } = await admin
    .from('leaderboards')
    .select('*')
    .eq('user_id', userId)
    .eq('game_type', gameType)
    .maybeSingle();

  if (!existing) {
    // First game for this user + game type
    await admin.from('leaderboards').insert({
      user_id: userId,
      game_type: gameType,
      games_played: 1,
      wins: result === 'win' ? 1 : 0,
      losses: result === 'loss' ? 1 : 0,
      draws: result === 'draw' ? 1 : 0,
      rating: Math.max(0, 1500 + ratingChange), // Start at 1500, floor at 0
    });
  } else {
    // Update existing entry
    const newRating = Math.max(0, existing.rating + ratingChange);
    await admin
      .from('leaderboards')
      .update({
        games_played: existing.games_played + 1,
        wins: existing.wins + (result === 'win' ? 1 : 0),
        losses: existing.losses + (result === 'loss' ? 1 : 0),
        draws: existing.draws + (result === 'draw' ? 1 : 0),
        rating: newRating,
        updated_at: new Date().toISOString(),
      })
      .eq('id', existing.id);
  }
}
