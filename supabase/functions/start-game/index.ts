import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { GameType } from '../_shared/types.ts';
import { buildInitialState, initialDbPhase } from '../_shared/game_setup.ts';

interface StartGameRequest {
  room_id: string;
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

    const body: StartGameRequest = await req.json();
    if (!body.room_id) return errorResponse('room_id is required', 400);

    // ── Fetch room ────────────────────────────────────────────────────────
    const { data: room, error: roomErr } = await admin
      .from('game_rooms')
      .select('*')
      .eq('id', body.room_id)
      .single();

    if (roomErr || !room) return errorResponse('Room not found', 404);

    // Only host can start
    if (room.created_by !== user.id) {
      return errorResponse('Only the host can start the game', 403, 'NOT_HOST');
    }
    if (room.status !== 'waiting') {
      return errorResponse('Game already started', 400, 'ALREADY_STARTED');
    }

    // ── Fetch human players ────────────────────────────────────────────────
    const { data: players } = await admin
      .from('room_players')
      .select('*')
      .eq('room_id', room.id)
      .eq('is_spectator', false)
      .order('seat_index', { ascending: true });

    // ── Merge with bots from room config ────────────────────────────────
    const bots: { id: string; difficulty: string; seat_index: number }[] =
      room.config?.bots ?? [];
    const humanIds = (players ?? []).map((p: { user_id: string }) => p.user_id);
    const botIds = bots.map((b) => b.id);
    const playerIds = [...humanIds, ...botIds];

    if (playerIds.length < 2) {
      return errorResponse('Not enough players', 400, 'NOT_ENOUGH_PLAYERS');
    }

    // ── Build initial game state ──────────────────────────────────────────
    const dealerIndex = Math.floor(Math.random() * playerIds.length);
    const stateData = buildInitialState(
      room.game_type as GameType,
      playerIds,
      dealerIndex,
      room.social_mode,
    );

    const dbPhase = initialDbPhase(stateData);

    // ── Update room status ────────────────────────────────────────────────
    const { error: roomUpdateErr } = await admin
      .from('game_rooms')
      .update({ status: 'playing' })
      .eq('id', room.id);

    if (roomUpdateErr) throw roomUpdateErr;

    // ── Update game state ─────────────────────────────────────────────────
    const { data: updatedState, error: stateErr } = await admin
      .from('game_states')
      .update({
        phase: dbPhase,
        state_data: stateData,
        round: 1,
      })
      .eq('room_id', room.id)
      .select();

    if (stateErr) throw stateErr;

    if (!updatedState || updatedState.length === 0) {
      return errorResponse('Game state not found for room', 404, 'STATE_NOT_FOUND');
    }

    // ── Update player activities ──────────────────────────────────────────
    for (const pid of playerIds) {
      await admin
        .from('profiles')
        .update({
          current_activity: {
            type: 'in_game',
            game_type: room.game_type,
            room_id: room.id,
            room_code: room.code,
            spectatable: true,
            joinable: false,
          },
        })
        .eq('id', pid);
    }

    return jsonResponse({
      game_type: room.game_type,
      state: stateData,
      phase: dbPhase,
      round: 1,
    });
  } catch (error) {
    console.error('Start game error:', error);
    return errorResponse('Internal server error', 500);
  }
});
