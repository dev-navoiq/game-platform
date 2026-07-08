# Story #52 Deployment Instructions

**Status:** Ready for Deployment
**Date:** 2026-07-07

---

## Changes Made

### Code Changes

**File:** `supabase/functions/_shared/rewards.ts`

**Changes:**
1. Added `updateLeaderboard()` function (lines 151-197)
   - Updates player leaderboard stats after game completion
   - Creates new entry for first game (rating=1500)
   - Updates existing entry (increments counters, adjusts rating)
   - Rating system: +25 win, -15 loss, 0 draw
   - Floor at 0 (cannot go negative)

2. Integrated leaderboard update into `grantGameEndRewards()` (lines 78-84)
   - Calls `updateLeaderboard()` for each human player
   - Wrapped in try-catch for error handling
   - Executes after rewards granted, before history recorded

---

## Deployment Steps

### Prerequisites

Ensure you have:
- Supabase CLI installed (`npm install -g supabase`)
- Access to staging and production project refs

### 1. Deploy to Staging

```bash
# Deploy the validate-move function (which imports rewards.ts)
supabase functions deploy validate-move --project-ref <STAGING_REF>

# Verify deployment
supabase functions list --project-ref <STAGING_REF>

# Monitor logs
supabase functions logs validate-move --project-ref <STAGING_REF>
```

### 2. Test on Staging

**Manual Test:**
1. Log in to staging app as test user
2. Play a game (Oh Hell recommended)
3. Complete the game
4. Check leaderboards table:
   ```sql
   SELECT * FROM leaderboards
   WHERE user_id = '<test_user_id>'
   AND game_type = 'oh_hell';
   ```
5. Verify:
   - Row created (if first game)
   - games_played incremented
   - wins/losses updated correctly
   - rating changed (+25 win, -15 loss)

**Expected Results:**
- See test cases: `docs/testing/story-52-test-cases.md`
- Run TC-L01, TC-L04, TC-L07 at minimum

### 3. Deploy to Production

**Only after staging tests pass:**

```bash
supabase functions deploy validate-move --project-ref <PRODUCTION_REF>

# Monitor logs for first hour
supabase functions logs validate-move --project-ref <PRODUCTION_REF> --follow
```

---

## Rollback Plan

If issues occur:

### Quick Rollback (Comment Out)

Edit `supabase/functions/_shared/rewards.ts`:

```typescript
// Comment out leaderboard update section in grantGameEndRewards:
for (const o of humanOutcomes) {
  await grantOne(admin, roomId, o, config, today);

  /* COMMENTED OUT FOR ROLLBACK
  const ratingChange = o.result === 'win' ? 25 : (o.result === 'loss' ? -15 : 0);
  try {
    await updateLeaderboard(admin, o.user_id, gameType, o.result, ratingChange);
  } catch (e) {
    console.error('updateLeaderboard failed', e);
  }
  */
}
```

Redeploy:
```bash
supabase functions deploy validate-move --project-ref <PROJECT_REF>
```

### Full Rollback (Git)

```bash
# Revert the commit
git revert <commit_hash>

# Redeploy
supabase functions deploy validate-move --project-ref <PROJECT_REF>
```

---

## Monitoring

### Key Metrics to Watch

**Edge Function Logs:**
- Look for: `updateLeaderboard failed` errors
- Acceptable error rate: < 0.1%

**Database Performance:**
- Monitor leaderboards table write latency
- Check for lock contention (should be none - one row per user+game_type)

**Functionality:**
- Game-end rewards still work (coins, XP granted)
- No increase in game completion errors

### Success Indicators

✅ No `updateLeaderboard failed` errors in logs
✅ Leaderboards table populated with new entries
✅ Ratings updating correctly (+25/-15)
✅ Stats separate per game type
✅ Game-end flow still completes in < 2 seconds

---

## Testing Checklist

Before deploying to production:

- [ ] Deployed to staging
- [ ] TC-L01 passed (new player first win)
- [ ] TC-L04 passed (existing player second game)
- [ ] TC-L07 passed (multi-game type separation)
- [ ] TC-L11 passed (bots excluded)
- [ ] No errors in staging logs (30 min monitoring)
- [ ] Game rewards still working
- [ ] Staging database shows correct leaderboard data

---

## Files Changed

1. `supabase/functions/_shared/rewards.ts` (modified)
2. `docs/story-52-implementation-plan.md` (new)
3. `docs/testing/story-52-test-cases.md` (new)
4. `docs/DEPLOY-STORY-52.md` (this file)

---

## Contact

If deployment issues occur:
- Check logs: `supabase functions logs validate-move`
- Review error in `updateLeaderboard` function
- Rollback if critical (see Rollback Plan above)

---

**Next Steps After Deployment:**
1. Update test execution log in `story-52-test-cases.md`
2. Mark Story #52 as complete in GitHub
3. Update Epic #48 Phase 0 status
