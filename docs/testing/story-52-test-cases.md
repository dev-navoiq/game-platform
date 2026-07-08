# Story #52: Leaderboard Updates - Test Cases

**Feature:** Automatic leaderboard updates when games complete
**Last Updated:** 2026-07-07
**Total Cases:** 12

---

## Test Case Overview

| Category | Test Count | Status |
|----------|------------|--------|
| New Player Tests | 3 | ⏳ Pending |
| Existing Player Tests | 3 | ⏳ Pending |
| Multi-Game Type Tests | 2 | ⏳ Pending |
| Edge Cases | 2 | ⏳ Pending |
| Rating Boundary Tests | 2 | ⏳ Pending |

---

## TC-L01: New Player - First Win

**Setup:**
- New user with no leaderboard entry
- Play Oh Hell game
- User wins the game

**Expected Result:**
```
leaderboards table:
  user_id: <user_id>
  game_type: 'oh_hell'
  games_played: 1
  wins: 1
  losses: 0
  draws: 0
  rating: 1525  (1500 + 25 for win)
  created_at: <timestamp>
  updated_at: <timestamp>
```

**Status:** ⏳ Pending

---

## TC-L02: New Player - First Loss

**Setup:**
- New user with no leaderboard entry
- Play Oh Hell game
- User loses the game

**Expected Result:**
```
leaderboards table:
  games_played: 1
  wins: 0
  losses: 1
  draws: 0
  rating: 1485  (1500 - 15 for loss)
```

**Status:** ⏳ Pending

---

## TC-L03: New Player - First Draw

**Setup:**
- New user with no leaderboard entry
- Play game that results in draw
- User draws the game

**Expected Result:**
```
leaderboards table:
  games_played: 1
  wins: 0
  losses: 0
  draws: 1
  rating: 1500  (no change for draw)
```

**Status:** ⏳ Pending

---

## TC-L04: Existing Player - Win After Win

**Setup:**
- User has existing entry: games=1, wins=1, losses=0, rating=1525
- Play second game
- User wins again

**Expected Result:**
```
leaderboards table:
  games_played: 2
  wins: 2
  losses: 0
  rating: 1550  (1525 + 25)
```

**Status:** ⏳ Pending

---

## TC-L05: Existing Player - Loss After Win

**Setup:**
- User has existing entry: games=1, wins=1, losses=0, rating=1525
- Play second game
- User loses

**Expected Result:**
```
leaderboards table:
  games_played: 2
  wins: 1
  losses: 1
  rating: 1510  (1525 - 15)
```

**Status:** ⏳ Pending

---

## TC-L06: Existing Player - Multiple Games

**Setup:**
- User plays 5 consecutive games
- Results: Win, Win, Loss, Win, Loss

**Expected Result:**
```
leaderboards table:
  games_played: 5
  wins: 3
  losses: 2
  rating: 1545  (1500 + 25 + 25 - 15 + 25 - 15)
```

**Status:** ⏳ Pending

---

## TC-L07: Multi-Game Type - Separate Entries

**Setup:**
- User plays Oh Hell → wins
- Same user plays Hearts → wins

**Expected Result:**
```
leaderboards table (2 rows):
Row 1:
  game_type: 'oh_hell'
  games_played: 1
  wins: 1
  rating: 1525

Row 2:
  game_type: 'hearts'
  games_played: 1
  wins: 1
  rating: 1525
```

**Status:** ⏳ Pending

---

## TC-L08: Multi-Game Type - Stats Don't Mix

**Setup:**
- User has Oh Hell: games=5, wins=3, rating=1545
- User plays Hearts → wins
- User plays Oh Hell again → loses

**Expected Result:**
```
Oh Hell leaderboard:
  games_played: 6  (5 + 1)
  wins: 3
  losses: 1
  rating: 1530  (1545 - 15)

Hearts leaderboard:
  games_played: 1
  wins: 1
  rating: 1525
```

**Status:** ⏳ Pending

---

## TC-L09: Rating Floor - Cannot Go Below Zero

**Setup:**
- User has rating: 10
- User loses game (rating change -15)

**Expected Result:**
```
leaderboards table:
  rating: 0  (floor applied, not -5)
```

**Status:** ⏳ Pending

---

## TC-L10: Rating Floor - Multiple Losses at Zero

**Setup:**
- User has rating: 0
- User loses 3 consecutive games

**Expected Result:**
```
leaderboards table:
  games_played: 3
  losses: 3
  rating: 0  (stays at 0, doesn't go negative)
```

**Status:** ⏳ Pending

---

## TC-L11: Bots Don't Get Leaderboard Entries

**Setup:**
- Room has 2 humans + 2 bots
- Human1 wins, Human2 loses
- Bot1 and Bot2 also have results

**Expected Result:**
```
leaderboards table:
  - 2 entries total (only humans)
  - Human1: wins=1, rating=1525
  - Human2: losses=1, rating=1485
  - No entries for Bot1 or Bot2
```

**Status:** ⏳ Pending

---

## TC-L12: Duplicate Game Doesn't Double-Update

**Setup:**
- Game finishes, grantGameEndRewards called
- Same game_room_id called again (edge case)

**Expected Result:**
```
leaderboards table:
  - Stats only updated once (protected by game_reward_grants guard)
  - games_played: 1 (not 2)
```

**Status:** ⏳ Pending

---

## Manual Testing Instructions

### Setup Test Environment

1. **Access Staging Database:**
   ```bash
   # Connect to staging Supabase
   supabase db remote commit
   ```

2. **Create Test Users:**
   ```sql
   -- Use existing test accounts or create new ones
   SELECT id, email FROM profiles WHERE email LIKE '%test%';
   ```

### Run Test Cases

**For TC-L01 (New Player First Win):**
1. Log in as new test user
2. Start Oh Hell game
3. Play to completion (win)
4. Query leaderboards:
   ```sql
   SELECT * FROM leaderboards
   WHERE user_id = '<test_user_id>'
   AND game_type = 'oh_hell';
   ```
5. Verify: games_played=1, wins=1, rating=1525

**For TC-L04 (Existing Player Win):**
1. Same user plays second game
2. Win again
3. Query leaderboards
4. Verify: games_played=2, wins=2, rating=1550

**For TC-L07 (Multi-Game Type):**
1. Same user plays different game type (Hearts)
2. Query: `SELECT * FROM leaderboards WHERE user_id = '<test_user_id>';`
3. Verify: 2 separate rows (oh_hell and hearts)

---

## Automated Test Plan (Future)

### Unit Tests (TypeScript)

Create: `supabase/functions/_shared/rewards.test.ts`

```typescript
Deno.test('updateLeaderboard: new player wins', async () => {
  // Mock admin client
  // Call updateLeaderboard(admin, userId, 'oh_hell', 'win', 25)
  // Assert: INSERT called with rating=1525
});

Deno.test('updateLeaderboard: existing player loses', async () => {
  // Mock existing row: rating=1525
  // Call updateLeaderboard(admin, userId, 'oh_hell', 'loss', -15)
  // Assert: UPDATE called with rating=1510
});

Deno.test('updateLeaderboard: rating floor at zero', async () => {
  // Mock existing row: rating=10
  // Call updateLeaderboard(admin, userId, 'oh_hell', 'loss', -15)
  // Assert: UPDATE called with rating=0 (not -5)
});
```

---

## Success Criteria

**All tests must pass:**
- ✅ New players get initial rating of 1500
- ✅ Wins increase rating by 25
- ✅ Losses decrease rating by 15
- ✅ Draws don't change rating
- ✅ Stats separate per game type
- ✅ Rating cannot go below 0
- ✅ Bots excluded from leaderboards
- ✅ Duplicate games protected by guard

---

## Test Execution Log

| Test ID | Executed By | Date | Result | Notes |
|---------|-------------|------|--------|-------|
| TC-L01 | - | - | ⏳ Pending | - |
| TC-L02 | - | - | ⏳ Pending | - |
| TC-L03 | - | - | ⏳ Pending | - |
| TC-L04 | - | - | ⏳ Pending | - |
| TC-L05 | - | - | ⏳ Pending | - |
| TC-L06 | - | - | ⏳ Pending | - |
| TC-L07 | - | - | ⏳ Pending | - |
| TC-L08 | - | - | ⏳ Pending | - |
| TC-L09 | - | - | ⏳ Pending | - |
| TC-L10 | - | - | ⏳ Pending | - |
| TC-L11 | - | - | ⏳ Pending | - |
| TC-L12 | - | - | ⏳ Pending | - |

---

## Related Documentation

- Implementation Plan: [story-52-implementation-plan.md](../story-52-implementation-plan.md)
- Code: [rewards.ts](../../supabase/functions/_shared/rewards.ts)
- Database Schema: [leaderboards table](../../supabase/migrations/20260226000000_initial_schema.sql)
