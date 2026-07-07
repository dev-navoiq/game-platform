# 26 — Social Features: Design & Build Plan

> Friend discovery, messaging, parties, invites, push notifications, and PTT voice.
> The social loop is the acquisition engine: **invite friends → play together → they invite friends.**
> Couples to identity ([23-identity-and-profiles.md](23-identity-and-profiles.md)): the social graph is
> registered-only and is a primary guest→registered conversion trigger.
>
> Status: **DESIGN LOCKED 2026-07-06.** Scope decisions confirmed (see §2).

---

## 0. What already exists (audit 2026-07-06)

The backend is further along than the product. Most tables/RLS exist; the gaps are discovery,
notifications, group play, and voice.

| Piece | State |
|---|---|
| `friendships` table + RLS + 3-tab Friends screen (friends/requests/blocked) | ✅ end-to-end |
| `user_blocks` + block enforcement (DM RLS, join-room host-block check) | ✅ end-to-end |
| **Friend discovery (search / add by anything)** | ❌ none — you can only act on requests that already exist |
| `direct_messages` (friend-only RLS, `text`/`game_invite`/`system` types, unread via `read_at`, `mark_thread_read` RPC) | ✅ end-to-end; inbox + thread screens live |
| DM game invites (create private room → `game_invite` DM w/ 30-min expiry → accept & join) | ✅ works, but hardcodes `social_mode='full'`, `max_players=4`; dead if recipient's app is closed |
| In-game chat `chat_messages` (player/spectator split, `ChatRules` social-mode matrix) | ✅ end-to-end |
| `quick_reactions` + emoji bar + 5-second floating bubbles | ✅ end-to-end |
| Mute votes (`mute_votes` + 50% DB trigger → `moderation_log`) + overlay UI | ✅ end-to-end |
| Presence: Realtime channel `global_lobby` (`presenceBootstrapProvider`) + `profiles.current_activity` (10s poll for activity detail) | ✅ end-to-end |
| Friend activity "join/watch" actions | ❌ TODO stubs (`home_screen.dart`, `friends_screen.dart`) |
| Group / party chat | ❌ nothing |
| `tournament_chat` table + RLS + models | ✅ table; ❌ no screen, no invite flow |
| Push notifications | ❌ `NotificationService` fully stubbed, no FCM/APNs, no token table |
| `notification_preferences` (9 categories + quiet hours, auto-created per user) | ✅ table; ❌ settings screen toggles not persisted (WIP banner) |
| Deep links / share links | ❌ none (no URL scheme, no universal links) |
| Voice | ❌ `StubVoiceService` ("coming soon" pill); `voice-token` edge fn exists but unverified/unwired |
| Reports (user-initiated) | ❌ no table; `moderation_log` is room-action log only |

---

## 1. Product framing — the social loop

```
Discover friend ──► Add ──► DM / Party ──► Invite to game ──► Play together
      ▲                                                            │
      └──────────── push notification re-engages ◄────────────────┘
```

Every pillar below serves one loop. Priorities follow from it:
1. **Push is the backbone** — without it, invites/DMs only work if both apps are foregrounded.
2. **Discovery feeds the graph** — no search = no friends = every other feature is idle.
3. **Party is the retention multiplier** — groups that move game-to-game are the stickiest cohort.
4. **Voice deepens sessions** — PTT keeps it cheap and moderatable (locked 2026-06-08 strategy).

---

## 2. Locked scope decisions (2026-07-06)

1. **Discovery = username search + friend code + recent players + share link.** No contact sync
   this phase (waits for phone auth P1 in identity plan).
2. **Chat scope = 1:1 DMs (exists) + a lightweight PARTY** — a group of friends that chats and
   moves from game to game together. No standalone persistent group chats (WhatsApp-style) this phase.
3. **Push notifications are P0 in this phase.** FCM for both platforms (APNs via Firebase on iOS).
4. **PTT voice IS in this phase** (LiveKit, free tier = push-to-talk only per [[voice-tiering-strategy]]).
5. Carried over from identity design (locked): **social graph is registered-only** — friends, DMs,
   parties require `account_type='registered'`. See §10 for the guest matrix.

---

## 3. Pillar A — Discovery & the friend graph

### 3.1 Username search
- `profiles.username` today: trigger-generated `guest_<uuid>` / `<prefix>_<uuid>`, no uniqueness
  guarantee designed for search. Add:
  - `unique index on lower(username)`; usernames become claimable at registration (identity build
    already adds a register form — add a username field there).
  - Validation: 3–20 chars, `[a-z0-9_]`, no leading `_`, reserved-word list (admin, gathr, system).
- Search is an **RPC, not open table reads**: `search_profiles(p_query text) returns setof
  (id, username, display_name, avatar_url, level, account_type)`:
  - `security definer`, prefix-match on `lower(username)`, `limit 10`, registered profiles only,
    excludes blocked-either-direction and self.
  - Rate-limit in the edge layer (or a simple per-user counter) — search is an enumeration surface.

### 3.2 Friend code
- `profiles.friend_code text unique` — 8-char Crockford base32 (no 0/O/1/I), generated at
  registration (and backfilled for existing registered users). **Separate from `referral_code`**
  (that one has economic meaning and anti-farm rules; conflating them turns "add me" into a coin faucet).
- Exact-match lookup goes through the same `search_profiles` RPC (query matches code format → code
  lookup, else username prefix).
- Profile screen shows "My friend code: `GTHR-XXXX-XXXX`" with copy + OS share sheet
  (share text embeds the deep link, §6).

### 3.3 Recent players
- Source: `room_players` of finished rooms (joined via `recent_games`, which
  `record_game_completion()` already writes per participant).
- RPC `get_recent_players(p_limit int default 20)`: distinct human co-players from your last N
  games, most recent first, annotated with `is_friend` / `request_pending`, excluding blocked.
- Surfaces:
  - **Game-over dialog**: "Played with `<name>` — [Add friend]" row (highest-intent moment).
  - **Friends screen** gets a 4th surface: "Suggested" section on the Friends tab (recent players
    not yet friends).

### 3.4 Friend request flow (upgraded)
- New **profile peek sheet** (`ProfilePeekSheet`): tap any player anywhere (search result, recent
  player, room roster, chat message author) → bottom sheet with avatar, username, level, mutuals
  count, and context actions: Add friend / Accept request / Message / Invite to game / Block / Report.
  This one component is the hub that makes every surface social.
- Friend request writes stay on the existing `friendships` insert (RLS already correct).
  Add DB constraint against duplicate reverse-direction rows:
  `unique (least(user_id, friend_id), greatest(user_id, friend_id))` — replaces the current
  one-directional unique, prevents A→B and B→A pending pairs.
- Accepting fires a push ("`<name>` accepted your friend request").

---

## 4. Pillar B — Messaging polish (1:1 DMs)

Existing DM stack stays. Additions:

1. **Unread badge on the app shell** — `unreadDmCountProvider` derived from `dmInboxProvider`;
   badge on the Messages nav icon + app icon badge count (via push payload `badge`).
2. **Typing indicator** — Realtime **broadcast** (not table writes) on channel `dm:{sorted-pair}`;
   throttled to 1 event / 3s; presence dot already exists.
3. **Message retraction UI** — RLS already allows sender delete; add long-press → "Remove message"
   (renders as "message removed" tombstone client-side).
4. **New DM message types** (extend the existing `message_type` check constraint):
   - `party_invite` — payload `{party_id, expires_at}` (§5)
   - `tournament_invite` — payload `{tournament_id, name, game_type, start_time}` (§6.3)
5. **Invite-card fixes**: the DM `game_invite` flow reuses the create-room form params once
   [[multiplayer-room-flow-debt]] M4 form ships (game invite sheet gains max-players/social-mode);
   until then keep hardcoded defaults but **fix Chess** (2 seats, not 4) in `_sendGameInvite`.
6. **Guest gating**: Messages tab for guests renders the registration upsell
   (per identity doc §2 — "add a friend" is a conversion trigger).

---

## 5. Pillar C — Party system (group play sessions)

A **party** is a small group (cap 8) of friends that chats and hops between games together.
Not a persistent named community — think Xbox party, not Discord server.

### 5.1 Tables

```sql
create table parties (
  id           uuid primary key default gen_random_uuid(),
  leader_id    uuid not null references profiles(id) on delete cascade,
  status       text not null default 'active' check (status in ('active','disbanded')),
  current_room_id uuid references game_rooms(id) on delete set null,
  created_at   timestamptz not null default now(),
  last_active_at timestamptz not null default now()
);

create table party_members (
  party_id   uuid not null references parties(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  role       text not null default 'member' check (role in ('leader','member')),
  joined_at  timestamptz not null default now(),
  primary key (party_id, user_id)
);
-- invariant: one ACTIVE party per user — a partial index can't reference parties.status,
-- so this is enforced in the party-join/party-invite edge fns + a membership trigger (see below)

create table party_messages (
  id         uuid primary key default gen_random_uuid(),
  party_id   uuid not null references parties(id) on delete cascade,
  sender_id  uuid not null references profiles(id) on delete cascade,
  content    text not null check (char_length(content) between 1 and 500),
  message_type text not null default 'text' check (message_type in ('text','system')),
  created_at timestamptz not null default now()
);
```
(Exact one-active-party enforcement: `party_members` can't carry a cross-table `where exists` in a
partial index — enforce in the `party-invite`/`party-join` edge fn + a trigger that checks the
joining user has no membership in another `status='active'` party.)

### 5.2 RLS
- `parties` / `party_members` / `party_messages`: SELECT for members only; membership INSERT via
  edge function only (invited users), leader can DELETE members (kick), any member can DELETE self
  (leave); messages INSERT by members, sender-only delete.
- Blocked users: `party-invite` edge fn refuses invites when a block exists in either direction
  between invitee and ANY current member (parties are small; keep them drama-free).

### 5.3 Flows
- **Create**: "Start a party" from Friends screen / profile peek sheet → creates party with self as
  leader → invite pickers (friends list, online-first).
- **Invite**: `party-invite` edge fn → inserts a `party_invite` DM (payload `{party_id}`) + push.
  Accept → `party-join` edge fn (validates cap 8, not blocked, no other active party) → member added.
- **Party → game**: leader picks a game → `create-room` (private) with `party_id` in config →
  `parties.current_room_id` set → **system message in party chat + push to members** → members get a
  one-tap "Join" (join-room with the party's room). Late joiners see "In game — join as spectator"
  when seats are full.
- **Chat**: party chat screen (reuse DM thread UI skeleton); Realtime `postgres_changes` on
  `party_messages` (add to publication). Party chat is also reachable **during the game** as a tab
  in the in-game chat panel (party tab appears when room has `party_id`).
- **Lifecycle**: leader "Disband" or auto-disband via cron edge fn when `last_active_at` > 24h.
  Leader leaving promotes the longest-tenured member.

### 5.4 Presence
- Party presence rides the existing `global_lobby` channel payload (`activity`/`room_id` already
  tracked); the party screen shows online/in-game per member with the existing
  `onlineUserIdsProvider` — no new presence infra.

---

## 6. Pillar D — Invites & deep links

### 6.1 Deep link infrastructure (new, shared by everything)
- Custom scheme `gathr://` + universal links `https://gathr.app/...` (AASA + assetlinks.json can be
  served from the existing Firebase Hosting used for the admin app, or the marketing domain).
- Package: `app_links` → feed into GoRouter. Routes:
  - `/join/{roomCode}` → join-by-code flow (already exists — just deep-link it)
  - `/add/{friendCode}` → profile peek sheet with Add friend
  - `/t/{tournamentId}` → tournament detail
- **Cold-start handling**: pending deep link parked until auth resolves; guests hitting `/add` get
  the registration upsell with the link preserved through registration.

### 6.2 Room share sheet
- Room screen (waiting state) gains "Invite" button →
  - friends picker (sends `game_invite` DMs, existing path), and
  - OS share sheet: *"Play Hearts with me on Gathr! gathr.app/join/AB3X9K"* — this is the
    **stranger-acquisition channel** (WhatsApp groups, iMessage).
- Wire the friend-activity `onAction` TODOs: friend `in_lobby` + joinable → join room; friend
  `in_game` → spectate.

### 6.3 Tournament invites
- `tournament_invite` DM type (payload above) + "Invite friends" button on tournament detail screen
  (any registered participant can invite; recipient taps → tournament detail → register).
- Tournament lifecycle pushes (via §7): registration confirmed, check-in open, bracket ready,
  "your match is ready" (match → room linking already exists in `tournament_matches.room_id`).
- `tournament_chat` gets its screen: a chat tab on tournament detail (table + RLS already exist;
  announcements pinned via `is_announcement`).

---

## 7. Pillar E — Push notifications (P0 backbone)

### 7.1 Client
- `firebase_messaging` (FCM handles APNs on iOS — reuse the existing Firebase project from
  Android CI / admin hosting). iOS: push capability + APNs key in the Apple Developer portal
  (see [[ios-deploy-quirks]] before touching ios/).
- Un-stub `NotificationService`: initialize, permission prompt (ask **in context** — first time a
  user sends a friend request / joins a party, not at app launch), foreground presentation via
  `flutter_local_notifications`, tap-routing through the deep-link handler (§6.1).

### 7.2 Token storage

```sql
create table device_push_tokens (
  user_id    uuid not null references profiles(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios','android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
```
- RLS: owner insert/update/delete/select. Refresh on `onTokenRefresh` + login; delete on logout.
  Prune tokens that FCM reports invalid (in the sender fn).

### 7.3 Server fan-out
- Shared helper `_shared/push.ts`: `sendPush(userIds, category, {title, body, data})` —
  1. loads `notification_preferences`, drops users with the category off,
  2. applies **quiet hours server-side** (store `profiles.timezone`, set from the client;
     quiet-hour-suppressed pushes are dropped, not queued — game invites are ephemeral anyway),
  3. FCM HTTP v1 (service-account JSON in function secrets), `data` carries the deep-link route.
- Triggering: **database webhooks** (Supabase → edge fn `notify-dispatch`) on INSERT into
  `direct_messages`, `friendships` (pending + accepted transitions), `party_messages` (throttled:
  skip if recipient pushed for this party in last 60s), plus direct calls from
  `party-invite`, `tournament-*` fns.
- Category mapping onto the existing 9 `notification_preferences` columns
  (`game_invites`, `friend_activity`, `tournament_updates`, …) — the schema already fits; DMs map
  to a new `chat_messages boolean not null default true` column (migration adds it).

### 7.4 Settings screen
- Persist the 9 toggles + quiet hours to `notification_preferences` (RLS already allows update).
  **Remove the `UnderConstructionBanner`** ([[beta-wip-banners]] protocol).

---

## 8. Pillar F — Voice (PTT, LiveKit)

Per locked [[voice-tiering-strategy]] (2026-06-08): **free tier = push-to-talk only.** No open mic
this phase for anyone (paid open-mic decided later with PTT data).

### 8.1 Infra
- **LiveKit Cloud** (starter tier) for beta — no SFU ops burden; revisit self-host at scale.
- Audit + finish the existing `voice-token` edge fn: verify JWT grant (`roomJoin`, `canPublish`,
  `canSubscribe`), room name = `voice:{room_id}`, identity = user id; **gate**: caller must be a
  member of the room AND `game_rooms.social_mode = 'full'` AND not vote-muted
  (`moderation_log` mute check). Short TTL (10 min) + client re-fetch — this is how mute-votes
  bite without LiveKit server API calls: next token refresh loses `canPublish`.
  (Also call LiveKit's server `mutePublishedTrack` from a small `voice-mute` edge fn when the mute
  trigger fires, so it takes effect immediately, not at TTL.)

### 8.2 Client
- `livekit_client` implementation of the existing `VoiceService` abstraction — lives in the app
  layer (`lib/features/social/data/livekit_voice_service.dart`), NOT in `social_core`
  (the package stays pure Dart; same pattern as the Supabase repos). Swap
  `voiceServiceProvider` from `StubVoiceService`.
- **PTT UX**: hold-to-talk button docked near the emoji bar; press = enable mic track, release =
  disable (`setMicrophoneEnabled`, not track pub/unpub — faster). Haptic on press; speaking ring
  on player avatars from `speakingStates`. Optional per-user local volume/mute (long-press avatar
  → peek sheet gains "Mute for me").
- Join is **opt-in** per room ("Join voice" chip replaces the "coming soon" pill); auto-disconnect
  on room leave. iOS: `UIBackgroundModes audio` + mic permission strings in Info.plist.
- Guests: voice = registered-only? **No** — voice follows the ROOM, not the graph; guests may
  PTT in rooms they're legitimately in (keeps the play-together hook). Guests still can't be
  invited via DM/party (no graph), so exposure is organic rooms only.

### 8.3 Moderation
- PTT itself is the first moderation layer (intent is legible, minutes are ~30% of open mic).
- Mute-vote pipeline extends to voice automatically (§8.1 token gate + immediate server mute).
- No STT moderation this phase; report category `voice` added to reports (§9).

---

## 9. Safety & moderation (cross-cutting)

1. **Reports table** (new — currently there is NO user-initiated report path):

```sql
create table user_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_id   uuid not null references profiles(id) on delete cascade,
  context     text not null check (context in ('dm','room_chat','party','voice','profile','game')),
  context_id  uuid,
  reason      text not null check (reason in ('harassment','spam','cheating','inappropriate_name','other')),
  detail      text check (char_length(detail) <= 500),
  status      text not null default 'open' check (status in ('open','reviewed','actioned','dismissed')),
  created_at  timestamptz not null default now()
);
```
   - RLS: reporter inserts/reads own; review is admin-only → **moderation queue goes in the admin
     web app Phase B** ([24-admin-web-app-brief.md](24-admin-web-app-brief.md)) with actions that
     write `moderation_log` (warn/mute/ban).
2. **Report entry points**: profile peek sheet + long-press on any chat message (attaches the
   message content snapshot into `detail`).
3. **Block coverage extends to new surfaces**: party invites (§5.2), search results (§3.1),
   recent players (§3.3). DM + join-room already enforce.
4. **Client profanity filter** (shared word-list in `social_core` `ChatRules.filterContent`) applied
   to chat/DM/party render — display-side masking, server keeps raw for moderation. Server-side
   moderation (LLM/API) deferred.
5. **Rate limits** in edge fns: friend requests (20/day), searches (30/min), party invites (30/day),
   DM sends stay RLS-guarded + client cooldown (2s, exists in ChatRules).

---

## 10. Identity gating matrix (from epic #57, applied to social)

| Capability | Guest | Registered |
|---|:--:|:--:|
| In-room chat / reactions / mute votes | ✅ | ✅ |
| PTT voice in rooms you're in | ✅ | ✅ |
| Join room by code / share link | ✅ | ✅ |
| Appear in search / have friend code | ❌ | ✅ |
| Send/accept friend requests, DMs | ❌ | ✅ |
| Parties (create/join) | ❌ | ✅ |
| Tournament invites | ❌ | ✅ |
| Report a player | ✅ | ✅ |

Room-scoped social is identity-free (it IS the game); graph-scoped social converts.
Enforcement: RLS `account_type='registered'` checks on `friendships`/`direct_messages` (tighten
existing policies) + party/search edge fns + UI upsell sheets (identity build ships the upsell
component; reuse it).

---

## 11. New backend surface (summary)

| Kind | Item | Pillar |
|---|---|---|
| Migration | `username` unique index + `friend_code` + `profiles.timezone` + `chat_messages` pref column | A, E |
| Migration | `search_profiles()` + `get_recent_players()` RPCs | A |
| Migration | bidirectional-unique on `friendships` | A |
| Migration | `parties`, `party_members`, `party_messages` (+ realtime publication) | C |
| Migration | `device_push_tokens` | E |
| Migration | `user_reports` | Safety |
| Migration | DM `message_type` extends: `party_invite`, `tournament_invite` | B, D |
| Edge fn | `notify-dispatch` (DB-webhook target) + `_shared/push.ts` | E |
| Edge fn | `party-invite`, `party-join`, `party-leave` (leave/kick/disband), `party-set-room` | C |
| Edge fn | `voice-token` (finish/gate) + `voice-mute` | F |
| Edge fn | cron: stale-party disband | C |
| Config | FCM service account secret; LiveKit keys; AASA/assetlinks hosting | E, F, D |

Realtime additions: `party_messages` → publication; `dm:{pair}` broadcast channel (typing);
existing `global_lobby` presence unchanged.

---

## 12. Build order

Dependency spine: **push first** (everything else fires through it), discovery second (feeds the
graph), then invites/party (consume both), voice last (independent, riskiest infra).

- **M0 — Push backbone** *(P0)*: FCM client + permission-in-context, `device_push_tokens`,
  `_shared/push.ts` + `notify-dispatch` webhooks for DM/friend-request, notification settings
  persistence (banner removed), deep-link route handling for notification taps (subset of §6.1).
- **M1 — Discovery**: username claim (with identity build's register form), friend code, `search_profiles` +
  `get_recent_players`, profile peek sheet, Add-friend surfaces (search UI, game-over row,
  Suggested section), request/accept pushes, bidirectional-unique migration.
- **M2 — Invites & deep links**: full `app_links` infra + AASA/assetlinks, room share sheet,
  friend-activity join/spectate wiring, `game_invite` Chess seat fix, tournament invites +
  tournament chat tab, tournament lifecycle pushes.
- **M3 — Party**: tables + RLS + edge fns, party screen (roster + chat), invite via DM+push,
  party→room flow with one-tap join, in-game party chat tab, stale-party cron.
- **M4 — PTT voice**: LiveKit Cloud setup, finish `voice-token` + `voice-mute`, `LiveKitVoiceService`,
  PTT button + speaking rings, mute-vote integration, iOS entitlements.
- **M5 — Safety net**: `user_reports` + report entry points, profanity filter, rate limits,
  admin moderation queue (admin app Phase B), guest-gating RLS tightening + upsell wiring.

M0 → M1 → M2 are strictly ordered. M3, M4 can parallelize after M2. M5 items land alongside the
feature that creates each surface where cheap (e.g., block checks in party fns ship with M3);
the admin queue is the only genuinely-last piece.

**External prerequisites** (can start today): Apple push key + capability, FCM service account,
LiveKit Cloud account, decision on the universal-link domain.

---

## 13. Explicitly deferred

- Contact sync / find-by-phone (needs phone auth, identity P1)
- Persistent named group chats & communities
- Open-mic voice for paid tiers (revisit with PTT harassment/cost data)
- STT / server-side voice moderation
- Global lobby chat (needs its own table + moderation posture — locked out of `direct_messages` by design)
- Guest→registered social-graph merge edge cases (guests have no graph, so nothing to merge — keep it that way)
- Spectator "cheer" reactions, gifting, profile decorations (economy tie-ins, post-economy-UI)
