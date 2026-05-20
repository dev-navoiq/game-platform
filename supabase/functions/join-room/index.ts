import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';

interface JoinRoomRequest {
  room_id?: string;
  room_code?: string;
  password?: string;
  as_spectator?: boolean;
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

    const body: JoinRoomRequest = await req.json();

    if (!body.room_id && !body.room_code) {
      return errorResponse('room_id or room_code is required', 400);
    }

    // ── Resolve room ──────────────────────────────────────────────────────
    let roomQuery = admin.from('game_rooms').select('*');
    if (body.room_id) {
      roomQuery = roomQuery.eq('id', body.room_id);
    } else {
      roomQuery = roomQuery.eq('code', body.room_code!);
    }
    const { data: room, error: roomError } = await roomQuery.single();

    if (roomError || !room) {
      return errorResponse('Room not found', 404, 'ROOM_NOT_FOUND');
    }

    // ── Check room status ─────────────────────────────────────────────────
    const asSpectator = body.as_spectator || false;
    if (!asSpectator && room.status !== 'waiting') {
      return errorResponse(
        'Game already started. Join as spectator?',
        400,
        'GAME_STARTED',
      );
    }
    if (asSpectator && !['waiting', 'playing'].includes(room.status)) {
      return errorResponse('Room is not active', 400, 'ROOM_INACTIVE');
    }

    // ── Check user not blocked by host ────────────────────────────────────
    const { data: block } = await admin
      .from('user_blocks')
      .select('id')
      .eq('blocker_id', room.created_by)
      .eq('blocked_id', user.id)
      .maybeSingle();

    if (block) {
      return errorResponse('You are blocked from this room', 403, 'BLOCKED');
    }

    // ── Check user not already in room ────────────────────────────────────
    const { data: existing } = await admin
      .from('room_players')
      .select('id')
      .eq('room_id', room.id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      return errorResponse('Already in this room', 400, 'ALREADY_IN_ROOM');
    }

    // ── Private room password check ───────────────────────────────────────
    if (room.is_private && room.password_hash) {
      if (!body.password) {
        return errorResponse('Password required', 401, 'PASSWORD_REQUIRED');
      }
      const encoder = new TextEncoder();
      const hashBuffer = await crypto.subtle.digest(
        'SHA-256',
        encoder.encode(body.password),
      );
      const hash = Array.from(new Uint8Array(hashBuffer))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
      if (hash !== room.password_hash) {
        return errorResponse('Incorrect password', 401, 'WRONG_PASSWORD');
      }
    }

    // ── Spectator slot check ──────────────────────────────────────────────
    if (asSpectator) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('subscription_tier')
        .eq('id', user.id)
        .single();

      const tier = profile?.subscription_tier || 'free';
      const maxSpectators = tier === 'max' ? 10 : tier === 'pro' ? 5 : 2;

      const { count } = await admin
        .from('room_players')
        .select('*', { count: 'exact', head: true })
        .eq('room_id', room.id)
        .eq('is_spectator', true);

      if ((count || 0) >= maxSpectators) {
        return errorResponse('Spectator slots full', 403, 'SPECTATOR_FULL');
      }
    }

    // ── Player capacity check ─────────────────────────────────────────────
    if (!asSpectator && room.current_players >= room.max_players) {
      return errorResponse('Room is full', 403, 'ROOM_FULL');
    }

    // ── Find next seat ────────────────────────────────────────────────────
    const { data: players } = await admin
      .from('room_players')
      .select('seat_index')
      .eq('room_id', room.id)
      .eq('is_spectator', false)
      .order('seat_index', { ascending: true });

    const occupiedSeats = new Set((players || []).map((p: { seat_index: number }) => p.seat_index));
    let seatIndex = 0;
    if (!asSpectator) {
      while (occupiedSeats.has(seatIndex)) seatIndex++;
    }

    // ── Determine team ────────────────────────────────────────────────────
    const teamGames = ['twenty_nine', 'spades', 'bridge'];
    const team = !asSpectator && teamGames.includes(room.game_type)
      ? seatIndex % 2
      : null;

    // ── Insert player ─────────────────────────────────────────────────────
    const { error: insertError } = await admin
      .from('room_players')
      .insert({
        room_id: room.id,
        user_id: user.id,
        seat_index: asSpectator ? -1 : seatIndex,
        team,
        is_ready: false,
        is_spectator: asSpectator,
      });

    if (insertError) throw insertError;

    // ── Update user activity ──────────────────────────────────────────────
    await admin
      .from('profiles')
      .update({
        current_activity: {
          type: asSpectator ? 'spectating' : 'in_lobby',
          game_type: room.game_type,
          room_id: room.id,
          room_code: room.code,
          joinable: false,
        },
      })
      .eq('id', user.id);

    return jsonResponse({
      room_id: room.id,
      seat_index: asSpectator ? -1 : seatIndex,
      is_spectator: asSpectator,
    });
  } catch (error) {
    console.error('Join room error:', error);
    return errorResponse('Internal server error', 500);
  }
});
