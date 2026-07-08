# Story #52: Leaderboard Updates Implementation Plan

**Part of:** Epic #48 Phase 0
**Depends on:** Story #51 (Grant Rewards)
**Status:** Ready for Implementation

---

## Overview

Automatically update player leaderboards when games complete, tracking win/loss records and skill ratings per game type.

---

## Implementation Approach

**Option Selected:** Edge Function Approach (in rewards.ts)

**Rationale:**
- Clean separation: RPC handles history, edge function handles rewards + rankings
- Already loops through player outcomes in `grantGameEndRewards`
- Easier to test and modify rating formulas
- Can add anti-cheat logic later

---

## Changes Required

### 1. Add `updateLeaderboard` Function

**Location:** `supabase/functions/_shared/rewards.ts`

**Function Signature:**
```typescript
async function updateLeaderboard(
  admin: SupabaseClient,
  userId: string,
  gameType: string,
  result: 'win' | 'loss' | 'draw',
  ratingChange: number
): Promise<void>
```

**Logic:**
1. Upsert leaderboards table for (user_id, game_type)
2. If new row → initialize with rating=1500, games_played=1
3. If existing → increment counters, adjust rating
4. Update: games_played, wins/losses/draws, rating, updated_at

---

### 2. Integrate into `grantGameEndRewards`

**Location:** Same file, after reward grants

**Add call:**
```typescript
for (const o of humanOutcomes) {
  await grantOne(admin, roomId, o, config, today);

  // NEW: Update leaderboard
  const ratingChange = o.result === 'win' ? 25 : (o.result === 'loss' ? -15 : 0);
  await updateLeaderboard(admin, o.user_id, gameType, o.result, ratingChange);
}
```

---

## Rating System (Simple Fixed Points)

| Result | Rating Change |
|--------|---------------|
| Win    | +25 points    |
| Loss   | -15 points    |
| Draw   | 0 points      |

**Starting Rating:** 1500
**Floor:** 0 (cannot go negative)

**Future:** Can upgrade to ELO-based system where rating change depends on opponent's rating.

---

## Database Operations

**Table:** `leaderboards` (already exists)

**Columns Used:**
- `user_id` (uuid)
- `game_type` (game_type enum)
- `games_played` (int)
- `wins` (int)
- `losses` (int)
- `draws` (int)
- `rating` (int)
- `updated_at` (timestamptz)

**Unique Constraint:** `(user_id, game_type)`

**Operation:** UPSERT (INSERT ... ON CONFLICT DO UPDATE)

---

## Testing Strategy

### Manual Testing (Staging)

1. **New Player Test:**
   - Play first game as new user
   - Verify: leaderboard row created with rating=1500
   - Win → rating=1525, games_played=1, wins=1

2. **Existing Player Test:**
   - Play second game
   - Verify: stats accumulate correctly
   - Loss → rating decreases, games_played increments

3. **Multiple Game Types:**
   - Play Oh Hell, then Hearts
   - Verify: separate leaderboard entries per game type

4. **Edge Cases:**
   - Draw result → rating unchanged
   - Rating floor → cannot go below 0

### Automated Tests (Future)

Create unit tests for:
- `updateLeaderboard` function
- Rating calculation logic
- UPSERT behavior (new vs existing)

---

## Deployment Steps

1. **Implement Changes**
   - Add `updateLeaderboard` function to rewards.ts
   - Integrate call into `grantGameEndRewards`

2. **Deploy to Staging**
   ```bash
   supabase functions deploy validate-move --project-ref <staging-ref>
   ```

3. **Verify on Staging**
   - Play test games
   - Check leaderboards table directly
   - Verify ratings update correctly

4. **Deploy to Production**
   - Same command with production project-ref
   - Monitor logs for errors

---

## Success Criteria

✅ Leaderboard row created for new players (rating=1500)
✅ Wins increment win counter and increase rating
✅ Losses increment loss counter and decrease rating
✅ Stats separate per game type
✅ No errors in edge function logs
✅ Existing game-end rewards still work

---

## Rollback Plan

If issues occur:
1. Remove `updateLeaderboard` call from `grantGameEndRewards`
2. Redeploy validate-move function
3. Leaderboard updates stop, but rewards continue working

---

## Related Files

- Implementation: `supabase/functions/_shared/rewards.ts`
- Entry point: `supabase/functions/validate-move/index.ts`
- Database schema: `supabase/migrations/20260226000000_initial_schema.sql` (leaderboards table)

---

## Time Estimate

- Implementation: 1 hour
- Testing: 1 hour
- Deployment + verification: 30 minutes
- **Total: 2-3 hours**
