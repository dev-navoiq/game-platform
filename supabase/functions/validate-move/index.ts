import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { MovePayload, mapDartPhaseToDb } from '../_shared/types.ts';
import { validateMove, applyMove } from '../_shared/game_rules/index.ts';

interface ValidateMoveRequest {
  room_id: string;
  move: MovePayload;
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

    const body: ValidateMoveRequest = await req.json();
    if (!body.room_id || !body.move) {
      return errorResponse('room_id and move are required', 400);
    }

    // ── Fetch game state ──────────────────────────────────────────────────
    const { data: gameState, error: stateErr } = await admin
      .from('game_states')
      .select('*')
      .eq('room_id', body.room_id)
      .single();

    if (stateErr || !gameState) {
      return errorResponse('Game not found', 404, 'GAME_NOT_FOUND');
    }

    // ── Fetch room for game_type ──────────────────────────────────────────
    const { data: room } = await admin
      .from('game_rooms')
      .select('game_type, status, config, created_by')
      .eq('id', body.room_id)
      .single();

    // Verify the move is from the authenticated user or a bot in the room
    const movePlayerId = body.move.player_id;
    if (movePlayerId !== user.id) {
      const bots: { id: string }[] = (room?.config as Record<string, unknown>)?.bots as { id: string }[] ?? [];
      const isBotInRoom = bots.some((b) => b.id === movePlayerId);
      if (!isBotInRoom) {
        return errorResponse('Move player_id must match authenticated user or a bot in the room', 403, 'PLAYER_MISMATCH');
      }
    }

    if (!room) return errorResponse('Room not found', 404);
    if (room.status !== 'playing') {
      return errorResponse('Game is not in progress', 400, 'NOT_PLAYING');
    }

    // ── Verify it's the player's turn ─────────────────────────────────────
    const stateData = gameState.state_data as Record<string, unknown>;
    // Skip turn check for phase-transition moves (validated by game rules)
    const turnFreeMoves = ['newRound'];
    if (!turnFreeMoves.includes(body.move.type) &&
        stateData.currentPlayerId && stateData.currentPlayerId !== body.move.player_id) {
      return errorResponse('Not your turn', 400, 'NOT_YOUR_TURN');
    }

    // ── Normalize move: ensure `data` sub-object exists ─────────────────
    // Client may send fields flat (e.g. { type, player_id, bid_value })
    // or nested (e.g. { type, player_id, data: { bid_value } }).
    const rawMove = body.move as Record<string, unknown>;
    if (!rawMove.data || typeof rawMove.data !== 'object') {
      const { type, player_id, ...rest } = rawMove;
      rawMove.data = rest;
    }
    const move = rawMove as MovePayload;

    // ── Validate move ─────────────────────────────────────────────────────
    const validationResult = validateMove(room.game_type, stateData, move);

    if (!validationResult.valid) {
      console.warn(
        `Invalid move attempt: room=${body.room_id} player=${body.move.player_id} ` +
        `type=${body.move.type} error=${validationResult.error_code}`,
      );
      return jsonResponse(validationResult, 400);
    }

    // ── Apply move ────────────────────────────────────────────────────────
    const newState = applyMove(room.game_type, stateData, move);
    const newPhase = (newState.phase as string) || 'playing';
    const dbPhase = mapDartPhaseToDb(newPhase);
    const newRound = (newState.roundNumber as number) ?? gameState.round;

    // ── Update state with optimistic locking ──────────────────────────────
    const { data: updated, error: updateErr } = await admin
      .from('game_states')
      .update({
        state_data: newState,
        phase: dbPhase,
        round: newRound,
      })
      .eq('room_id', body.room_id)
      .eq('updated_at', gameState.updated_at)
      .select('id')
      .maybeSingle();

    if (updateErr) throw updateErr;
    if (!updated) {
      return errorResponse('State conflict — retry', 409, 'VERSION_CONFLICT');
    }

    // ── Record valid move ─────────────────────────────────────────────────
    const nextSeqNo = await getNextSequenceNo(admin, body.room_id);
    await admin.from('game_moves').insert({
      room_id: body.room_id,
      player_id: move.player_id,
      move_type: move.type,
      move_data: move.data,
      round: gameState.round,
      sequence_no: nextSeqNo,
    });

    // ── Handle game end ───────────────────────────────────────────────────
    if (newPhase === 'gameEnd' || newPhase === 'complete') {
      await admin
        .from('game_rooms')
        .update({ status: 'finished' })
        .eq('id', body.room_id);

      // Clear player activities
      const { data: players } = await admin
        .from('room_players')
        .select('user_id')
        .eq('room_id', body.room_id);

      if (players) {
        for (const p of players) {
          await admin
            .from('profiles')
            .update({ current_activity: null })
            .eq('id', p.user_id);
        }
      }
    }

    return jsonResponse({
      valid: true,
      new_state: newState,
      events: (newState.events as unknown[]) || [],
    });
  } catch (error) {
    console.error('Validate move error:', error);
    return errorResponse('Internal server error', 500);
  }
});

async function getNextSequenceNo(
  admin: ReturnType<typeof getSupabaseAdmin>,
  roomId: string,
): Promise<number> {
  const { data } = await admin
    .from('game_moves')
    .select('sequence_no')
    .eq('room_id', roomId)
    .order('sequence_no', { ascending: false })
    .limit(1);

  return (data?.[0]?.sequence_no || 0) + 1;
}
