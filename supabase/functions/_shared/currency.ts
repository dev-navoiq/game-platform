import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Credit coins or gems to a user.
 * Updates the profile balance and inserts a currency_transaction record.
 * Uses the admin (service-role) client to bypass RLS.
 */
export async function creditCurrency(
  admin: SupabaseClient,
  userId: string,
  currency: 'coins' | 'gems',
  amount: number,
  reason: string,
  referenceId?: string,
): Promise<{ balance_after: number }> {
  if (amount <= 0) throw new Error('Credit amount must be positive');

  // Read current balance
  const { data: profile, error: readErr } = await admin
    .from('profiles')
    .select(currency)
    .eq('id', userId)
    .single();

  if (readErr || !profile) throw new Error(`Profile not found: ${userId}`);

  const currentBalance = (profile as Record<string, number>)[currency] ?? 0;
  const newBalance = currentBalance + amount;

  // Update balance
  const { error: updateErr } = await admin
    .from('profiles')
    .update({ [currency]: newBalance })
    .eq('id', userId);

  if (updateErr) throw new Error(`Failed to update ${currency}: ${updateErr.message}`);

  // Log transaction
  await admin.from('currency_transactions').insert({
    user_id: userId,
    currency,
    amount,
    balance_after: newBalance,
    reason,
    ...(referenceId ? { reference_id: referenceId } : {}),
  });

  return { balance_after: newBalance };
}

/**
 * Debit coins or gems from a user.
 * Returns error if insufficient balance.
 */
export async function debitCurrency(
  admin: SupabaseClient,
  userId: string,
  currency: 'coins' | 'gems',
  amount: number,
  reason: string,
  referenceId?: string,
): Promise<{ balance_after: number }> {
  if (amount <= 0) throw new Error('Debit amount must be positive');

  const { data: profile, error: readErr } = await admin
    .from('profiles')
    .select(currency)
    .eq('id', userId)
    .single();

  if (readErr || !profile) throw new Error(`Profile not found: ${userId}`);

  const currentBalance = (profile as Record<string, number>)[currency] ?? 0;
  if (currentBalance < amount) {
    throw new Error(`Insufficient ${currency}: have ${currentBalance}, need ${amount}`);
  }

  const newBalance = currentBalance - amount;

  const { error: updateErr } = await admin
    .from('profiles')
    .update({ [currency]: newBalance })
    .eq('id', userId);

  if (updateErr) throw new Error(`Failed to update ${currency}: ${updateErr.message}`);

  await admin.from('currency_transactions').insert({
    user_id: userId,
    currency,
    amount: -amount,
    balance_after: newBalance,
    reason,
    ...(referenceId ? { reference_id: referenceId } : {}),
  });

  return { balance_after: newBalance };
}

/**
 * Grant XP to a user and handle level-ups.
 * Returns the updated xp, level, and xp_to_next_level.
 */
export async function grantXp(
  admin: SupabaseClient,
  userId: string,
  xpAmount: number,
): Promise<{ xp: number; level: number; xp_to_next_level: number; leveled_up: boolean }> {
  const { data: profile, error } = await admin
    .from('profiles')
    .select('xp, level, xp_to_next_level')
    .eq('id', userId)
    .single();

  if (error || !profile) throw new Error(`Profile not found: ${userId}`);

  let xp = profile.xp + xpAmount;
  let level = profile.level;
  let xpNeeded = profile.xp_to_next_level;
  let leveledUp = false;

  // Level-up loop
  while (xp >= xpNeeded) {
    xp -= xpNeeded;
    level++;
    leveledUp = true;
    // Level curve: 500 (1-5), 750 (6-10), 1000 (11-20), 1500 (21-30), 2000 (31-50), 2500 (50+)
    if (level <= 5) xpNeeded = 500;
    else if (level <= 10) xpNeeded = 750;
    else if (level <= 20) xpNeeded = 1000;
    else if (level <= 30) xpNeeded = 1500;
    else if (level <= 50) xpNeeded = 2000;
    else xpNeeded = 2500;
  }

  await admin
    .from('profiles')
    .update({ xp, level, xp_to_next_level: xpNeeded })
    .eq('id', userId);

  return { xp, level, xp_to_next_level: xpNeeded, leveled_up: leveledUp };
}

/**
 * Add XP to the user's progress in the active season (if any).
 * Levels up at a flat 1000 XP per season level, capped at season.max_level.
 * No-op when there is no active season. Mirrors the logic previously private to
 * claim-challenge-reward so game-end and tournament rewards share one path.
 */
export async function addSeasonXp(
  admin: SupabaseClient,
  userId: string,
  xp: number,
): Promise<void> {
  if (xp <= 0) return;

  const { data: season } = await admin
    .from('seasons')
    .select('id, max_level')
    .eq('is_active', true)
    .maybeSingle();

  if (!season) return;

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
