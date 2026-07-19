import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { jsonResponse, errorResponse } from '../_shared/validation.ts';
import {
  startTournament,
  startTournamentMatch,
  forfeitTournamentMatch,
} from '../_shared/tournament_report.ts';

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
    };

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

        // Culprit: whoever the game is waiting on; worse seed as fallback.
        const turnId = (gs.state_data as { currentPlayerId?: string } | null)?.currentPlayerId;
        let culprit: string | null = null;
        if (turnId && (turnId === match.player1_id || turnId === match.player2_id)) {
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
          for (const pid of [match.player1_id, match.player2_id]) {
            if (pid) {
              await admin.from('profiles').update({ current_activity: null }).eq('id', pid);
            }
          }
          summary.forfeited.push({ match_id: match.id as string, forfeited_user: culprit });
        } catch (e) {
          console.error(`tick: forfeit failed for match ${match.id}:`, e);
        }
      }
    }

    return jsonResponse({ ok: true, ...summary });
  } catch (error) {
    console.error('tournament-tick error:', error);
    return errorResponse('Internal server error', 500);
  }
});
