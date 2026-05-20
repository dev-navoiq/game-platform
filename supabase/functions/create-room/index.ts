import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import {
  GameType,
  RoomSocialMode,
  GAME_PLAYER_LIMITS,
} from '../_shared/types.ts';

interface CreateRoomRequest {
  game_type: GameType;
  max_players: number;
  is_private: boolean;
  password?: string;
  social_mode?: RoomSocialMode;
  config?: Record<string, unknown>;
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

    const body: CreateRoomRequest = await req.json();

    // ── Validate request ──────────────────────────────────────────────────
    const validationError = validateRequest(body);
    if (validationError) {
      return errorResponse(validationError, 400);
    }

    // ── Private room limit check ──────────────────────────────────────────
    if (body.is_private) {
      const canCreate = await checkPrivateRoomLimit(supabase, user.id);
      if (!canCreate) {
        return errorResponse('Private room limit reached for today', 403, 'ROOM_LIMIT');
      }
    }

    // ── Generate room code ────────────────────────────────────────────────
    const code = generateRoomCode();

    // ── Hash password if provided ─────────────────────────────────────────
    let passwordHash: string | null = null;
    if (body.password) {
      const encoder = new TextEncoder();
      const data = encoder.encode(body.password);
      const hashBuffer = await crypto.subtle.digest('SHA-256', data);
      passwordHash = Array.from(new Uint8Array(hashBuffer))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
    }

    // ── Create room ───────────────────────────────────────────────────────
    const socialMode = body.social_mode || 'full';
    const { data: room, error: roomError } = await supabase
      .from('game_rooms')
      .insert({
        code,
        game_type: body.game_type,
        status: 'waiting',
        social_mode: socialMode,
        created_by: user.id,
        max_players: body.max_players,
        is_private: body.is_private,
        password_hash: passwordHash,
        config: body.config || {},
      })
      .select()
      .single();

    if (roomError) throw roomError;

    // ── Add host as first player ──────────────────────────────────────────
    const { error: playerError } = await supabase
      .from('room_players')
      .insert({
        room_id: room.id,
        user_id: user.id,
        seat_index: 0,
        team: isTeamGame(body.game_type) ? 0 : null,
        is_ready: false,
        is_spectator: false,
      });

    if (playerError) {
      // Cleanup room on failure
      await supabase.from('game_rooms').delete().eq('id', room.id);
      throw playerError;
    }

    // ── Create initial game state ─────────────────────────────────────────
    const { error: stateError } = await admin.from('game_states').insert({
      room_id: room.id,
      phase: 'waiting',
      state_data: {
        game_type: body.game_type,
        initialized: false,
        players: [],
      },
      round: 0,
    });

    if (stateError) {
      // Cleanup room on failure
      await admin.from('game_rooms').delete().eq('id', room.id);
      throw stateError;
    }

    // ── Update user activity ──────────────────────────────────────────────
    await supabase
      .from('profiles')
      .update({
        current_activity: {
          type: 'in_lobby',
          game_type: body.game_type,
          room_id: room.id,
          room_code: code,
          joinable: !body.is_private,
        },
      })
      .eq('id', user.id);

    return jsonResponse({
      room_id: room.id,
      code,
      invite_link: `gameplatform://room/${code}`,
    });
  } catch (error) {
    console.error('Error creating room:', error);
    return errorResponse('Internal server error', 500);
  }
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

function validateRequest(body: CreateRoomRequest): string | null {
  if (!body.game_type) return 'game_type is required';
  if (!body.max_players || body.max_players < 2 || body.max_players > 8) {
    return 'max_players must be between 2 and 8';
  }

  const limits = GAME_PLAYER_LIMITS[body.game_type];
  if (!limits) return `Unknown game type: ${body.game_type}`;

  if (body.max_players < limits.min || body.max_players > limits.max) {
    return `${body.game_type} requires ${limits.min}-${limits.max} players`;
  }

  if (
    body.social_mode &&
    !['full', 'chat_only', 'silent', 'focus'].includes(body.social_mode)
  ) {
    return 'Invalid social_mode';
  }

  return null;
}

function generateRoomCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const values = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(values)
    .map((v) => chars[v % chars.length])
    .join('');
}

function isTeamGame(gameType: GameType): boolean {
  return ['twenty_nine', 'spades', 'bridge'].includes(gameType);
}

async function checkPrivateRoomLimit(
  supabase: ReturnType<typeof getSupabaseClient>,
  userId: string,
): Promise<boolean> {
  const { data: profile } = await supabase
    .from('profiles')
    .select('subscription_tier')
    .eq('id', userId)
    .single();

  const tier = profile?.subscription_tier || 'free';
  if (tier === 'pro' || tier === 'max') return true; // Unlimited

  // Free tier: 1 private room per day
  const today = new Date().toISOString().split('T')[0];
  const { count } = await supabase
    .from('game_rooms')
    .select('*', { count: 'exact', head: true })
    .eq('created_by', userId)
    .eq('is_private', true)
    .gte('created_at', `${today}T00:00:00`);

  return (count || 0) < 1;
}
