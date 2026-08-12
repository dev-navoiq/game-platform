import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { jsonResponse, errorResponse } from '../_shared/validation.ts';
import {
  startTournament,
  startTournamentMatch,
  forfeitTournamentMatch,
} from '../_shared/tournament_report.ts';
import { sendPush } from '../_shared/push.ts';
import {
  TournamentTemplate,
  nextTemplateStartMs,
  spawnTemplateInstance,
} from '../_shared/tournament_templates.ts';

// ─────────────────────────────────────────────────────────────────────────────
// tournament-tick — the tournament lifecycle heartbeat (prompts/25 §T1 + §T2).
// Invoked every minute by pg_cron (see migration 20260719000000) via
// invoke_tournament_tick(); any authenticated caller may also poke it.
//
// Intentionally safe to invoke publicly/concurrently: it only performs actions
// that are due by the clock, and every downstream op is status-gated
// (startTournament rejects non-registration states; forfeit skips completed
// matches; match repair is idempotent). A racing duplicate tick loses those
// gates and no-ops.
//
// Phases:
//   1. Due starts — tournaments whose start_time has passed: start (min met)
//      or cancel + refund (min not met; startTournament's own path).
//   2. Repair — 'ready' matches that somehow have no room: open them.
//   3. Stall sweep — in-progress matches whose game saw no state write for
//      STALL_FORFEIT_MINUTES: forfeit the player whose turn it is
//      (state_data.currentPlayerId — uniform across all game builders),
//      falling back to the worse seed. Room is marked abandoned + presence
//      cleared so clients stop.
// ─────────────────────────────────────────────────────────────────────────────

const STALL_FORFEIT_MINUTES = 10;
const MAX_STARTS_PER_TICK = 20;
const MAX_SWEEPS_PER_TICK = 20;
const MAX_MATERIALIZE_PER_TICK = 20;

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const admin = getSupabaseAdmin();
    const nowIso = new Date().toISOString();
    const summary = {
      started: [] as string[],
      cancelled: [] as string[],
      start_errors: [] as { id: string; code?: string }[],
      repaired: 0,
      forfeited: [] as { match_id: string; forfeited_user: string }[],
      rooms_expired: 0,
      materialized: [] as string[],
    };

    // ── -1. Materialize template instances (#251) ──────────────────────────
    // For each active clock-driven template whose next occurrence is within
    // its registration lead window, create the instance. Idempotent via
    // uq_tournament_template_instance (template_id, start_time) — a racing
    // duplicate tick loses the unique index and no-ops.
    {
      const { data: templates } = await admin
        .from('tournament_templates')
        .select('*')
        .eq('active', true)
        .limit(MAX_MATERIALIZE_PER_TICK);

      for (const t of (templates ?? []) as TournamentTemplate[]) {
        try {
          if (t.schedule_kind === 'sitgo') {
            // #252 backstop: sit&gos spawn instantly on fill-start inside
            // tournament-register; here we cover the FIRST spawn for a new
            // template and self-heal if the instant path ever failed. The
            // partial unique index (one open instance per template) makes
            // a redundant spawn a 23505 no-op.
            const { count } = await admin
              .from('tournaments')
              .select('id', { count: 'exact', head: true })
              .eq('template_id', t.id)
              .eq('status', 'registration');
            if ((count ?? 0) === 0) {
              if (await spawnTemplateInstance(admin, t) === 'created') {
                summary.materialized.push(t.id);
              }
            }
            continue;
          }

          const startMs = nextTemplateStartMs(t, Date.now());
          if (startMs === null) continue;
          if (startMs - Date.now() > t.registration_lead_minutes * 60_000) continue;

          const result = await spawnTemplateInstance(
              admin, t, new Date(startMs).toISOString());
          if (result === 'created') summary.materialized.push(t.id);
        } catch (e) {
          console.error(`tick: materialize threw for template ${t.id}:`, e);
        }
      }
    }

    // ── 0. Check-in window announcements (§T6) ─────────────────────────────
    // Push "check in now" once per tournament when its window opens.
    // settings.check_in_notified is the once-flag.
    const { data: windows } = await admin
      .from('tournaments')
      .select('id, name, start_time, check_in_minutes, settings')
      .eq('status', 'registration')
      .gt('check_in_minutes', 0)
      .gt('start_time', nowIso)
      .limit(50);
    for (const w of windows ?? []) {
      const settings = (w.settings ?? {}) as Record<string, unknown>;
      if (settings.check_in_notified) continue;
      const opensAt = new Date(w.start_time).getTime() - w.check_in_minutes * 60_000;
      if (Date.now() < opensAt) continue;
      try {
        const { data: parts } = await admin
          .from('tournament_participants')
          .select('user_id')
          .eq('tournament_id', w.id);
        await admin.from('tournaments')
          .update({ settings: { ...settings, check_in_notified: true } })
          .eq('id', w.id);
        await sendPush(admin, (parts ?? []).map((p) => p.user_id as string), 'tournament_updates', {
          title: w.name ?? 'Tournament',
          body: 'Check-in is open — confirm your spot before the start!',
          data: { route: `/tournament/${w.id}` },
        });
      } catch (e) {
        console.error(`tick: check-in announce failed for ${w.id}:`, e);
      }
    }

    // ── 0b. Start reminder push at T-15 (Epic #250 Phase 2) ────────────────
    // One "starting soon" push to everyone registered. settings.
    // start_reminder_notified is the once-flag (same pattern as check-in).
    // Sit&go horizon instances never qualify (start_time is days out).
    const { data: startingSoon } = await admin
      .from('tournaments')
      .select('id, name, start_time, settings')
      .eq('status', 'registration')
      .gt('start_time', nowIso)
      .lte('start_time', new Date(Date.now() + 15 * 60_000).toISOString())
      .limit(50);
    for (const s of startingSoon ?? []) {
      const settings = (s.settings ?? {}) as Record<string, unknown>;
      if (settings.start_reminder_notified) continue;
      try {
        const { data: parts } = await admin
          .from('tournament_participants')
          .select('user_id')
          .eq('tournament_id', s.id);
        await admin.from('tournaments')
          .update({ settings: { ...settings, start_reminder_notified: true } })
          .eq('id', s.id);
        if ((parts ?? []).length > 0) {
          await sendPush(admin, (parts ?? []).map((p) => p.user_id as string), 'tournament_updates', {
            title: s.name ?? 'Tournament',
            body: 'Starting in 15 minutes — get ready!',
            data: { route: `/tournament/${s.id}` },
          });
        }
      } catch (e) {
        console.error(`tick: start reminder failed for ${s.id}:`, e);
      }
    }

    // ── 1. Due starts ──────────────────────────────────────────────────────
    const { data: due } = await admin
      .from('tournaments')
      .select('id, name')
      .in('status', ['registration', 'starting'])
      .lte('start_time', nowIso)
      .limit(MAX_STARTS_PER_TICK);

    for (const t of due ?? []) {
      try {
        const r = await startTournament(admin, t.id);
        if (r.status === 'started') summary.started.push(t.id);
        else if (r.status === 'cancelled') summary.cancelled.push(t.id);
        else summary.start_errors.push({ id: t.id, code: r.code });
      } catch (e) {
        console.error(`tick: start failed for ${t.id}:`, e);
        summary.start_errors.push({ id: t.id, code: 'EXCEPTION' });
      }
    }

    // ── 2. Repair: ready matches with no room (normally opened at bracket
    //      insert / advance; this catches a crash between those steps) ──────
    const { data: unopened } = await admin
      .from('tournament_matches')
      .select('id')
      .eq('status', 'ready')
      .is('room_id', null)
      .limit(MAX_SWEEPS_PER_TICK);
    for (const m of unopened ?? []) {
      try {
        if (await startTournamentMatch(admin, m.id)) summary.repaired++;
      } catch (e) {
        console.error(`tick: repair failed for match ${m.id}:`, e);
      }
    }

    // ── 3. Stall sweep ─────────────────────────────────────────────────────
    const { data: live } = await admin
      .from('tournament_matches')
      .select('id, room_id, player1_id, player2_id, player1_seed, player2_seed')
      .eq('status', 'in_progress')
      .not('room_id', 'is', null)
      .limit(200);

    if (live && live.length > 0) {
      const cutoff = new Date(Date.now() - STALL_FORFEIT_MINUTES * 60_000).toISOString();
      const roomIds = live.map((m) => m.room_id as string);
      const { data: stalledStates } = await admin
        .from('game_states')
        .select('room_id, state_data, updated_at')
        .in('room_id', roomIds)
        .lt('updated_at', cutoff)
        .limit(MAX_SWEEPS_PER_TICK);

      const matchByRoom = new Map(live.map((m) => [m.room_id as string, m]));
      for (const gs of stalledStates ?? []) {
        const match = matchByRoom.get(gs.room_id as string);
        if (!match) continue;

        // Everyone seated in the room (2 for 1v1, 4 for team matches).
        const { data: seated } = await admin
          .from('room_players')
          .select('user_id')
          .eq('room_id', gs.room_id);
        const seatedIds = (seated ?? []).map((r) => r.user_id as string);

        // Culprit: whoever the game is waiting on (any seated player — for
        // team matches this may be a non-captain); worse seed as fallback.
        // forfeitTournamentMatch resolves the culprit's whole side.
        const turnId = (gs.state_data as { currentPlayerId?: string } | null)?.currentPlayerId;
        let culprit: string | null = null;
        if (turnId && seatedIds.includes(turnId)) {
          culprit = turnId;
        } else {
          const s1 = match.player1_seed ?? 9999;
          const s2 = match.player2_seed ?? 9999;
          culprit = s1 <= s2 ? (match.player2_id as string) : (match.player1_id as string);
        }
        if (!culprit) continue;

        try {
          await forfeitTournamentMatch(admin, match.id as string, culprit);
          // Close the room so clients stop treating it as live.
          await admin.from('game_rooms').update({ status: 'abandoned' }).eq('id', gs.room_id);
          const toClear = seatedIds.length ? seatedIds : [match.player1_id, match.player2_id].filter(Boolean) as string[];
          for (const pid of toClear) {
            await admin.from('profiles').update({ current_activity: null }).eq('id', pid);
          }
          summary.forfeited.push({ match_id: match.id as string, forfeited_user: culprit });
        } catch (e) {
          console.error(`tick: forfeit failed for match ${match.id}:`, e);
        }
      }
    }

    // ── 4. Waiting-room sweeper ────────────────────────────────────────────
    // Rooms abandoned in 'waiting' lived forever — 31 ghosts up to 54 days
    // old were polluting matchmaking candidates and room lists (#217). A
    // lobby idle for an hour is dead; sweep it. (Tournament match rooms are
    // born 'playing' and never pass through here.)
    const staleRoomCutoff = new Date(Date.now() - 60 * 60_000).toISOString();
    const { data: expiredRooms } = await admin
      .from('game_rooms')
      .update({ status: 'abandoned' })
      .eq('status', 'waiting')
      .lt('created_at', staleRoomCutoff)
      .select('id');
    summary.rooms_expired = (expiredRooms ?? []).length;

    return jsonResponse({ ok: true, ...summary });
  } catch (error) {
    console.error('tournament-tick error:', error);
    return errorResponse('Internal server error', 500);
  }
});
