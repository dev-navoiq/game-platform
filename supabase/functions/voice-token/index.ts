import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts';

interface VoiceTokenRequest {
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

    const body: VoiceTokenRequest = await req.json();
    if (!body.room_id) return errorResponse('room_id is required', 400);

    // ── Verify user is in the room ────────────────────────────────────────
    const { data: roomPlayer } = await admin
      .from('room_players')
      .select('id')
      .eq('room_id', body.room_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!roomPlayer) {
      return errorResponse('Not in room', 403, 'NOT_IN_ROOM');
    }

    // ── Check room social mode allows voice ───────────────────────────────
    const { data: room } = await admin
      .from('game_rooms')
      .select('social_mode')
      .eq('id', body.room_id)
      .single();

    if (!room) return errorResponse('Room not found', 404);

    if (room.social_mode !== 'full') {
      return errorResponse(
        'Voice chat not available in this social mode',
        400,
        'VOICE_DISABLED',
      );
    }

    // ── Get subscription tier + username ───────────────────────────────────
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_tier, username')
      .eq('id', user.id)
      .single();

    const tier = profile?.subscription_tier || 'free';

    // Free tier gets 2-min teaser; Pro/Max get 1 hour
    const durationSeconds = tier === 'free' ? 120 : 3600;

    // ── Generate LiveKit JWT ──────────────────────────────────────────────
    const apiKey = Deno.env.get('LIVEKIT_API_KEY');
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET');
    const livekitUrl = Deno.env.get('LIVEKIT_URL');

    if (!apiKey || !apiSecret) {
      throw new Error('LiveKit credentials not configured');
    }

    const roomName = `game_${body.room_id}`;
    const participantName = profile?.username || user.id;

    // Build LiveKit-compatible JWT
    const secret = new TextEncoder().encode(apiSecret);
    const now = Math.floor(Date.now() / 1000);

    const token = await new jose.SignJWT({
      iss: apiKey,
      sub: user.id,
      name: participantName,
      video: {
        room: roomName,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
      },
    })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuedAt(now)
      .setExpirationTime(now + durationSeconds)
      .setNotBefore(now)
      .sign(secret);

    return jsonResponse({
      token,
      room_name: roomName,
      server_url: livekitUrl,
      duration_seconds: durationSeconds,
    });
  } catch (error) {
    console.error('Voice token error:', error);
    return errorResponse('Failed to generate voice token', 500);
  }
});
