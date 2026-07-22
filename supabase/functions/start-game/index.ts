import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { startRoomSession } from '../_shared/room_start.ts';

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

    // ── Start the session (shared with join-room's auto-start) ────────────
    const result = await startRoomSession(admin, room);
    if ('error' in result) {
      const status = result.error_code === 'STATE_NOT_FOUND' ? 404 : 400;
      return errorResponse(result.error, status, result.error_code);
    }

    return jsonResponse({
      game_type: room.game_type,
      state: result.state,
      phase: result.phase,
      round: 1,
    });
  } catch (error) {
    console.error('Start game error:', error);
    return errorResponse('Internal server error', 500);
  }
});
