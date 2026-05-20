import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { GameType, GAME_PLAYER_LIMITS } from '../_shared/types.ts';

interface MatchmakingRequest {
  game_type: GameType;
  player_count?: number;
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

    const body: MatchmakingRequest = await req.json();
    if (!body.game_type) return errorResponse('game_type is required', 400);

    const limits = GAME_PLAYER_LIMITS[body.game_type];
    if (!limits) return errorResponse('Unknown game type', 400);

    const targetPlayers = body.player_count || limits.min;

    // ── Get user's rating ─────────────────────────────────────────────────
    const { data: leaderboard } = await supabase
      .from('leaderboards')
      .select('rating')
      .eq('user_id', user.id)
      .eq('game_type', body.game_type)
      .maybeSingle();

    const userRating = leaderboard?.rating || 1000;

    // ── Check subscription for priority ───────────────────────────────────
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_tier')
      .eq('id', user.id)
      .single();

    const tier = profile?.subscription_tier || 'free';
    const hasPriority = tier === 'pro' || tier === 'max';
    const ratingRange = hasPriority ? 100 : 200;

    // ── Search for matching rooms ─────────────────────────────────────────
    const { data: candidates } = await admin
      .from('game_rooms')
      .select('id, created_by, current_players, max_players, code')
      .eq('game_type', body.game_type)
      .eq('status', 'waiting')
      .eq('is_private', false)
      .lt('current_players', targetPlayers);

    // ── Filter by rating proximity ────────────────────────────────────────
    const matchingRooms: typeof candidates = [];
    if (candidates) {
      for (const room of candidates) {
        const { data: hostRating } = await admin
          .from('leaderboards')
          .select('rating')
          .eq('user_id', room.created_by)
          .eq('game_type', body.game_type)
          .maybeSingle();

        const hostElo = hostRating?.rating || 1000;
        if (Math.abs(hostElo - userRating) <= ratingRange) {
          matchingRooms.push(room);
        }
      }
    }

    if (matchingRooms.length > 0) {
      // Priority users get the best match; free users get random
      const room = hasPriority
        ? matchingRooms[0]
        : matchingRooms[Math.floor(Math.random() * matchingRooms.length)];

      // Find next available seat
      const { data: players } = await admin
        .from('room_players')
        .select('seat_index')
        .eq('room_id', room.id)
        .eq('is_spectator', false);

      const occupied = new Set((players || []).map((p: { seat_index: number }) => p.seat_index));
      let seatIndex = 0;
      while (occupied.has(seatIndex)) seatIndex++;

      const teamGames = ['twenty_nine', 'spades', 'bridge'];
      const team = teamGames.includes(body.game_type) ? seatIndex % 2 : null;

      const { error: joinErr } = await admin
        .from('room_players')
        .insert({
          room_id: room.id,
          user_id: user.id,
          seat_index: seatIndex,
          team,
          is_ready: false,
          is_spectator: false,
        });

      if (joinErr) throw joinErr;

      // Update activity
      await admin
        .from('profiles')
        .update({
          current_activity: {
            type: 'in_lobby',
            game_type: body.game_type,
            room_id: room.id,
            room_code: room.code,
            joinable: false,
          },
        })
        .eq('id', user.id);

      return jsonResponse({
        action: 'joined',
        room_id: room.id,
        seat_index: seatIndex,
      });
    }

    // ── No match found — create new room ──────────────────────────────────
    const code = generateCode();
    const { data: newRoom, error: createErr } = await admin
      .from('game_rooms')
      .insert({
        code,
        game_type: body.game_type,
        status: 'waiting',
        social_mode: profile?.preferred_social_mode || 'full',
        created_by: user.id,
        max_players: targetPlayers,
        is_private: false,
        config: { matchmaking: true },
      })
      .select()
      .single();

    if (createErr) throw createErr;

    await admin.from('room_players').insert({
      room_id: newRoom.id,
      user_id: user.id,
      seat_index: 0,
      team: ['twenty_nine', 'spades', 'bridge'].includes(body.game_type) ? 0 : null,
      is_ready: false,
      is_spectator: false,
    });

    await admin.from('game_states').insert({
      room_id: newRoom.id,
      phase: 'waiting',
      state_data: { game_type: body.game_type, initialized: false, players: [] },
      round: 0,
    });

    await admin
      .from('profiles')
      .update({
        current_activity: {
          type: 'in_lobby',
          game_type: body.game_type,
          room_id: newRoom.id,
          room_code: code,
          joinable: true,
        },
      })
      .eq('id', user.id);

    return jsonResponse({
      action: 'created',
      room_id: newRoom.id,
      seat_index: 0,
    });
  } catch (error) {
    console.error('Matchmaking error:', error);
    return errorResponse('Matchmaking failed', 500);
  }
});

function generateCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const values = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(values).map((v) => chars[v % chars.length]).join('');
}
