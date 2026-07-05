import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { forfeitTournamentMatch } from '../_shared/tournament_report.ts';

interface LeaveRoomRequest {
  room_id: string;
  // Caller's intent. Affects analytics + future UX (e.g. "you forfeited"
  // banner vs. silent dismiss). Not currently persisted — the slot itself
  // is the source of truth (disconnected_at IS NOT NULL == bot-subbed).
  reason?: 'forfeited' | 'left' | 'disconnected';
}

interface BotEntry {
  id: string;
  difficulty: string;
  seat_index: number;
  substitute_for?: string;
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

    const body: LeaveRoomRequest = await req.json();
    if (!body.room_id) return errorResponse('room_id is required', 400);
    const reason = body.reason ?? 'left';

    // ── Load room ────────────────────────────────────────────────────────
    const { data: room, error: roomErr } = await admin
      .from('game_rooms')
      .select(
        'id, status, current_host_id, created_by, max_players, config, ' +
          'auto_bot_difficulty',
      )
      .eq('id', body.room_id)
      .single();
    if (roomErr || !room) return errorResponse('Room not found', 404);

    // ── Load caller's row ────────────────────────────────────────────────
    const { data: row } = await admin
      .from('room_players')
      .select('id, seat_index, is_spectator, disconnected_at')
      .eq('room_id', room.id)
      .eq('user_id', user.id)
      .maybeSingle();

    // Idempotent: if the user already isn't in the room, treat as success.
    // Avoids client-side races where realtime delete fires twice.
    if (!row) {
      return jsonResponse({
        room_id: room.id,
        already_left: true,
      });
    }

    const liveHostId = room.current_host_id ?? room.created_by;
    const wasHost = liveHostId === user.id;
    const isPlayingGame = room.status === 'playing';

    // ── Tournament match: forfeit to the opponent (no bot substitution) ──
    // Competitive integrity — a disconnect hands the match to the opponent
    // and advances the bracket, rather than silently subbing a bot.
    const tournamentMatchId =
      (room.config as Record<string, unknown> | null)?.tournament_match_id as string | undefined;
    if (isPlayingGame && !row.is_spectator && tournamentMatchId) {
      await admin
        .from('room_players')
        .update({ disconnected_at: new Date().toISOString() })
        .eq('id', row.id);
      await admin.from('game_rooms').update({ status: 'finished' }).eq('id', room.id);
      try {
        await forfeitTournamentMatch(admin, tournamentMatchId, user.id);
      } catch (e) {
        console.error('forfeitTournamentMatch failed', e);
      }
      return jsonResponse({ room_id: room.id, forfeited: true });
    }

    // ── Phase A: handle the caller's row ─────────────────────────────────
    if (!isPlayingGame || row.is_spectator) {
      // Lobby / finished room, or a spectator: just remove the row.
      // No substitution needed; no game in progress to keep moving.
      await admin
        .from('room_players')
        .delete()
        .eq('id', row.id);

      // Recompute current_players = (humans not spectating) + bot count.
      // We avoid trusting the counter here because earlier states may have
      // drifted (the old "add bots indefinitely after forfeit" bug bumped
      // it past max_players in some rooms).
      const { count: humanCount } = await admin
        .from('room_players')
        .select('*', { count: 'exact', head: true })
        .eq('room_id', room.id)
        .eq('is_spectator', false);
      const botCount = ((room.config?.bots as BotEntry[]) ?? []).length;
      await admin
        .from('game_rooms')
        .update({ current_players: (humanCount ?? 0) + botCount })
        .eq('id', room.id);
    } else {
      // Game in progress: park the slot for rejoin and attach a substitute
      // bot inheriting the human's user_id. The bot controller on the
      // host's client treats config.bots[].id as a player ID — using the
      // human's UUID means playerOrder in the game state never has to
      // change, and rejoin is just "clear disconnected_at + remove this
      // entry from config.bots".
      const bots = ((room.config?.bots as BotEntry[]) ?? []);
      const alreadySubbed = bots.some((b) => b.id === user.id);
      const difficulty = (room as { auto_bot_difficulty?: string })
        .auto_bot_difficulty ?? 'medium';

      const updatedBots: BotEntry[] = alreadySubbed
        ? bots
        : [
            ...bots,
            {
              id: user.id,
              difficulty,
              seat_index: row.seat_index,
              substitute_for: user.id,
            },
          ];

      await admin
        .from('room_players')
        .update({ disconnected_at: new Date().toISOString() })
        .eq('id', row.id);

      const newConfig = {
        ...(room.config ?? {}),
        bots: updatedBots,
      };
      await admin
        .from('game_rooms')
        .update({ config: newConfig })
        .eq('id', room.id);
    }

    // ── Phase B: host transfer (if caller was the live host) ─────────────
    // Pick the next-seat active (non-disconnected, non-spectator, non-bot)
    // human. We can't pick a bot — bots don't have an authenticated session
    // to make RPC calls.
    if (wasHost) {
      const { data: nextHost } = await admin
        .from('room_players')
        .select('user_id, seat_index')
        .eq('room_id', room.id)
        .eq('is_spectator', false)
        .is('disconnected_at', null)
        .neq('user_id', user.id)
        .order('seat_index', { ascending: true })
        .limit(1)
        .maybeSingle();

      if (nextHost) {
        await admin
          .from('game_rooms')
          .update({ current_host_id: nextHost.user_id })
          .eq('id', room.id);
      }
      // If no one to transfer to, abandon path below will close the room.
    }

    // ── Phase C: abandon if no live humans remain ────────────────────────
    const { count: liveHumanCount } = await admin
      .from('room_players')
      .select('*', { count: 'exact', head: true })
      .eq('room_id', room.id)
      .eq('is_spectator', false)
      .is('disconnected_at', null);

    let roomAbandoned = false;
    if (
      (liveHumanCount ?? 0) === 0 &&
      ['waiting', 'playing'].includes(room.status)
    ) {
      // No humans → no one will rejoin to take back the slot, and bot-only
      // rooms shouldn't persist. Mark abandoned, blank the state so a
      // future stale-client never pulls cached data, and clear bots so the
      // next "create room" with the same code (improbable but possible)
      // starts clean.
      await admin
        .from('game_rooms')
        .update({
          status: 'abandoned',
          config: {
            ...(room.config ?? {}),
            bots: [],
          },
        })
        .eq('id', room.id);

      // state_data is NOT NULL with default '{}' — reset to empty object,
      // not null.
      await admin
        .from('game_states')
        .update({
          state_data: {},
          phase: 'waiting',
        })
        .eq('room_id', room.id);

      roomAbandoned = true;
    }

    // ── Phase D: clear caller's current_activity ─────────────────────────
    await admin
      .from('profiles')
      .update({ current_activity: null })
      .eq('id', user.id);

    return jsonResponse({
      room_id: room.id,
      reason,
      room_abandoned: roomAbandoned,
      host_transferred: wasHost && !roomAbandoned,
    });
  } catch (error) {
    console.error('Leave room error:', error);
    return errorResponse('Internal server error', 500);
  }
});
