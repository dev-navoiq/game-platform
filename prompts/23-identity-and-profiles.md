# 23 — Identity & Player Profiles

> Guest / registered / subscriber identity model, login methods, account linking, and profile design.
> Tightly coupled to the economy ([22-tournament-economy-design.md](22-tournament-economy-design.md)):
> **identity decides where coins/gems/XP live and who can touch the gem economy.**
>
> Status: **DESIGN ONLY.** Decisions locked 2026-06-30.

---

## 0. What already exists (audit 2026-06-30)

| Piece | State |
|---|---|
| Anonymous / guest sign-in | ✅ enabled (`config.toml` `enable_anonymous_sign_ins = true`); guest gets `guest_<id>` profile at free tier |
| Email + password sign-in | ✅ works (`login_screen.dart`, `auth_service.dart`); `enable_confirmations = false` |
| **Registration form** | ❌ stub — `register_screen.dart` = "coming in a future session" |
| Sign in with Apple / Google | ⚠️ code stubs in `auth_service.dart`, **OAuth disabled** in config (no client IDs) |
| Phone / Facebook / magic-link | ❌ none |
| `profiles` table | ✅ has coins, gems, xp, level, subscription_tier, referral_code, current_activity; **no `account_type`/`is_guest`** |
| Profile auto-create trigger `handle_new_user()` | ✅ guests → `guest_<uuid>`, email → `<prefix>_<uuid>`, auto referral_code + notification_preferences |
| **Guest → registered upgrade / account linking** | ❌ does not exist — the key gap |
| Subscription tier gating | ✅ read in `create-room` (private-room limit) + RevenueCat webhook |

---

## 1. Identity is two orthogonal axes

```
Axis 1 — ACCOUNT TYPE (identity permanence):   Guest ──► Registered
Axis 2 — SUBSCRIPTION TIER (entitlements):      Free ──► Pro ──► Max
```
- A **Guest is always Free** (stores require a recoverable account to purchase).
- A **Registered** user is Free, Pro, or Max.
- Axis 2 = existing `subscription_tier`. Axis 1 = new `account_type` (guest|registered).
- The two are independent; don't conflate them.

---

## 2. Capability matrix

**DECISION (locked): guests live in the COIN economy only; registration unlocks the GEM economy.**
Gems sit next to real money (bought/won/spent on premium) — anonymous accounts must not touch hard
currency, IAP, or social (fraud / chargeback / laundering surface).

| Capability | Guest | Free | Pro | Max |
|---|:--:|:--:|:--:|:--:|
| Instant play / vs bots | ✅ | ✅ | ✅ | ✅ |
| Earn **coins** + XP | ✅ | ✅ | ✅ | ✅ |
| Free + **coin** tournaments | ✅ | ✅ | ✅ | ✅ |
| Earn / hold / buy **gems** | ❌ | ✅ | ✅ | ✅ |
| **Gem** tournaments + Gem Cups (win gems) | ❌ | ✅ | ✅ | ✅ |
| Ranked / MMR + seasonal gem payout | ❌ | ✅ | ✅ | ✅ |
| Friends / DM / social | ❌ | ✅ | ✅ | ✅ |
| IAP / subscribe | ❌ | ✅ | — | — |
| Cloud save / cross-device / recovery | ❌ | ✅ | ✅ | ✅ |
| Host tournaments | ❌ | ❌ | ✅ | ✅ |

**Upgrade trigger:** when a guest tries to enter a Gem Cup, claim a gem reward, add a friend, or play
ranked → prompt: *"Create a free account to unlock gems, tournaments & friends — and keep your coins +
level forever."* The gem gate IS the conversion funnel.

---

## 3. Account linking (guest → registered) — native, no migration

**The audit's "migration table" is unnecessary.** Supabase converts an anonymous user to permanent
**keeping the same `auth.users.id`**:
- Email: `updateUser({ email, password })` (+ optional confirm).
- Apple/Google/Facebook: `linkIdentity({ provider })`.

Because the UID is unchanged, the `profiles` row (coins, XP, level, everything) **stays attached
automatically** — no data transfer, no `account_links` table.

`is_anonymous` flips `true → false` on conversion. Sync `profiles.account_type` via a trigger on
`auth.users` UPDATE (or set it in the upgrade edge function).

### 3.1 Conflict: target identity already has an account
**DECISION (locked): discard guest progress, sign into the existing account (with a clear warning).**
Simple, ships now. Build balance-merge later only if support volume justifies it.
```
guest upgrades to identity X
   ├─ X is new      → link in place, same UID, progress kept ✅
   └─ X exists      → warn "You already have an account — signing in will discard this guest's
                       progress." → sign into existing account, abandon guest profile.
```

---

## 4. Login methods (build all — phased)

**DECISION (locked): support the full suite.** Apple is **mandatory on iOS** the moment any other
social login is offered (App Store guideline 4.8).

| Method | Priority | Work needed |
|---|---|---|
| Guest (anonymous) | ✅ done | — |
| Email + password | P0 | **build register form** + guest-upgrade flow (sign-in already works) |
| Magic link / email OTP | P0 | passwordless option on the email provider (cheap to add alongside email) |
| Sign in with **Apple** | P0 (iOS) | enable provider + client/secret in `config.toml`; un-stub `signInWithApple()` |
| Sign in with **Google** | P0 | enable provider + client IDs (iOS + Android); un-stub `signInWithGoogle()` |
| **Phone / OTP** | P1 | enable phone provider + SMS sender (Twilio/MessageBird — has per-SMS cost); expected default for India-skewed card/Ludo audience |
| **Facebook** | P2 | enable provider + Facebook app review/privacy overhead |

---

## 5. Profile design

Split **public** (shown to others) vs **private** (owner only); enforce via RLS.

**Public:** username, display_name, avatar_url (+ equipped avatar-frame skin), level/prestige badge,
country (optional), lifetime stats — games/tournaments played, tournament wins, best finish, current
rank tier, season level, equipped cosmetics. (Stats can be a VIEW over `recent_games` +
`tournament_participants`, not stored columns.)

**Private:** email/identities, coins, gems, subscription_tier + expiry, settings, notification prefs.

**Schema additions (proposed ⊕):**
- `profiles.account_type` enum `guest | registered` (default from `is_anonymous`; synced on upgrade).
- `profiles.country` text (optional, for leaderboards/flags).
- `profiles.last_active_at` timestamptz (for guest cleanup + presence).
- Username: auto `guest_<id>` for guests; **prompt to choose a real unique username on upgrade**.

---

## 6. Abuse guardrails (fall out of guest play)
- **Referrals require registration** — a guest referee must not count toward referral rewards (else
  infinite self-referral farm). Gate referral tier-1 on `account_type = registered`.
- **Rate-limit guest creation per device** (device fingerprint) to limit multi-accounting.
- **Stale-guest cleanup** — prune anonymous users inactive ~60 days with no meaningful progress, so the
  auth table doesn't bloat (every install = a new anon user).
- **Welcome gem grant on registration** (⊕ e.g. +50💎, configurable in `economy_config`) — guests can't
  *earn* gems, so first-gems-on-signup is a strong, cheap conversion hook.

---

## 7. Impact on the economy design (#22)
- The gem **skill bridge** (Gem Cups, ranked seasonal payout) is **registered-only** — guests are
  coin-economy only. Clean: registering = the door into the entire gem economy.
- Add guest-related knobs to `economy_config`: `welcome_gem_grant`, `guest_creation_per_device_limit`,
  `stale_guest_days`.

---

## 8. Build order (none built yet)
- **Phase A — Registration + email/social login**: build register form; enable + wire Apple, Google,
  magic-link; guest-upgrade (`updateUser`/`linkIdentity`) with discard-on-conflict.
- **Phase B — Identity model**: `account_type` column + `is_anonymous` sync trigger; gate gem economy
  / social / IAP on `registered`; welcome gem grant.
- **Phase C — Profiles**: public/private split + RLS; stats view; username-on-upgrade; avatar/cosmetics.
- **Phase D — Phone/OTP + Facebook**: SMS provider; Facebook review.
- **Phase E — Abuse & ops**: referral registration gate, guest rate-limit, stale-guest cleanup job.

---

## 9. Locked decisions (2026-06-30)
1. **Guests are coin-economy only**; gems / gem tournaments / IAP / social / ranked require registration.
2. **Login suite:** Email + Apple + Google + Guest (baseline) **plus** Phone/OTP, Facebook, and
   magic-link/email-OTP. Apple mandatory on iOS.
3. **Guest→registered conflict:** discard guest progress, sign into existing account (warn first).
4. **Account linking:** native Supabase anonymous upgrade (same UID) — no migration table.
