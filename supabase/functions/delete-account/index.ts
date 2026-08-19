import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';

// #270 — self-service account deletion (App Store 5.1.1(v)).
//
// The caller deletes THEMSELVES only. profiles.id cascades from
// auth.users, and the data tables cascade from profiles (recent_games,
// currency_transactions, participants, …). Denormalized history other
// players own (opponent_names text, final_standings jsonb) survives by
// design; profile lookups for the deleted id must null-fallback in UI.
//
// Guards: refuse while the user is in a live game or an active
// tournament — deleting mid-match would strand opponents; the client
// tells the user to finish/withdraw first.
serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;
  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const uid = auth.user.id;

    // ── Guard: live game ────────────────────────────────────────────────
    const { data: liveRooms } = await admin
      .from('room_players')
      .select('room_id, game_rooms!inner(status)')
      .eq('user_id', uid)
      .in('game_rooms.status', ['waiting', 'playing']);
    if ((liveRooms ?? []).length > 0) {
      return errorResponse(
        'Leave your active game room before deleting your account.',
        409, 'ACTIVE_GAME');
    }

    // ── Guard: active tournament ────────────────────────────────────────
    const { data: liveTournaments } = await admin
      .from('tournament_participants')
      .select('tournament_id, tournaments!inner(status)')
      .eq('user_id', uid)
      .in('tournaments.status', ['registration', 'starting', 'in_progress']);
    if ((liveTournaments ?? []).length > 0) {
      return errorResponse(
        'Withdraw from your active tournaments before deleting your account.',
        409, 'ACTIVE_TOURNAMENT');
    }

    // ── Best-effort pre-clean of push tokens (avoid ghost pushes even if
    // any FK is missing), then the cascade-triggering deletion. ─────────
    await admin.from('device_push_tokens').delete().eq('user_id', uid);

    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) {
      console.error(`delete-account failed for ${uid}:`, delErr);
      return errorResponse('Deletion failed — try again or contact support.',
        500, 'DELETE_FAILED');
    }
    return jsonResponse({ ok: true });
  } catch (e) {
    console.error('delete-account error:', e);
    return errorResponse('Internal server error', 500);
  }
});
