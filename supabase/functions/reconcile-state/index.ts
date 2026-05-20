import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';

interface ReconcileRequest {
  room_id: string;
}

/**
 * Read-only function: returns the authoritative game state and recent moves.
 * Called by clients when they detect desync.
 */
serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: ReconcileRequest = await req.json();
    if (!body.room_id) return errorResponse('room_id is required', 400);

    // ── Verify user is in the room ────────────────────────────────────────
    const { data: player } = await admin
      .from('room_players')
      .select('id, is_spectator')
      .eq('room_id', body.room_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!player) {
      return errorResponse('Not in room', 403, 'NOT_IN_ROOM');
    }

    // ── Fetch authoritative state ─────────────────────────────────────────
    const { data: gameState, error: stateErr } = await admin
      .from('game_states')
      .select('*')
      .eq('room_id', body.room_id)
      .single();

    if (stateErr || !gameState) {
      return errorResponse('Game state not found', 404);
    }

    // ── Fetch recent moves (last 20) ──────────────────────────────────────
    const { data: recentMoves } = await admin
      .from('game_moves')
      .select('player_id, move_type, move_data, round, sequence_no, created_at')
      .eq('room_id', body.room_id)
      .order('sequence_no', { ascending: false })
      .limit(20);

    // ── Fetch room info ───────────────────────────────────────────────────
    const { data: room } = await admin
      .from('game_rooms')
      .select('game_type, status, social_mode')
      .eq('id', body.room_id)
      .single();

    // ── If spectator, redact hidden info (e.g., other players' hands) ────
    let stateData = gameState.state_data;
    if (player.is_spectator) {
      stateData = redactForSpectator(stateData as Record<string, unknown>);
    }

    return jsonResponse({
      state_data: stateData,
      phase: gameState.phase,
      round: gameState.round,
      updated_at: gameState.updated_at,
      game_type: room?.game_type,
      status: room?.status,
      social_mode: room?.social_mode,
      recent_moves: (recentMoves || []).reverse(),
    });
  } catch (error) {
    console.error('Reconcile state error:', error);
    return errorResponse('Internal server error', 500);
  }
});

/**
 * Redact hidden information from state for spectators.
 * Removes player hands to prevent cheating.
 */
function redactForSpectator(
  stateData: Record<string, unknown>,
): Record<string, unknown> {
  const redacted = { ...stateData };

  // Replace hands with card counts only
  if (redacted.hands && typeof redacted.hands === 'object') {
    const hands = redacted.hands as Record<string, unknown[]>;
    const cardCounts: Record<string, number> = {};
    for (const [pid, hand] of Object.entries(hands)) {
      cardCounts[pid] = Array.isArray(hand) ? hand.length : 0;
    }
    redacted.hands = undefined;
    redacted.handCounts = cardCounts;
  }

  // Remove trump suit if not revealed (Twenty-Nine specific)
  if (redacted.trumpSuit && !redacted.trumpRevealed) {
    redacted.trumpSuit = 'hidden';
  }

  return redacted;
}
