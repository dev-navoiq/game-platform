import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';

// Check in for a tournament with a check-in window (prompts/25 §T6).
// Valid only while the window is open: from (start_time - check_in_minutes)
// until the tournament starts. Idempotent — checking in twice is fine.
interface CheckInRequest { tournament_id: string; }

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: CheckInRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400);

    const { data: t } = await admin
      .from('tournaments')
      .select('id, status, start_time, check_in_minutes')
      .eq('id', body.tournament_id)
      .single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if ((t.check_in_minutes ?? 0) <= 0) {
      return errorResponse('This tournament has no check-in', 400, 'NO_CHECK_IN');
    }
    if (t.status !== 'registration') {
      return errorResponse('Check-in is closed', 409, 'CHECK_IN_CLOSED');
    }
    const windowOpen =
      new Date(t.start_time).getTime() - t.check_in_minutes * 60_000;
    if (Date.now() < windowOpen) {
      return errorResponse('Check-in has not opened yet', 409, 'CHECK_IN_NOT_OPEN');
    }

    const { data: updated } = await admin
      .from('tournament_participants')
      .update({ status: 'checked_in', checked_in_at: new Date().toISOString() })
      .eq('tournament_id', t.id)
      .eq('user_id', user.id)
      .in('status', ['registered', 'checked_in'])
      .select('id');
    if (!updated || updated.length === 0) {
      return errorResponse('You are not registered for this tournament', 404, 'NOT_REGISTERED');
    }

    const { count } = await admin
      .from('tournament_participants')
      .select('*', { count: 'exact', head: true })
      .eq('tournament_id', t.id)
      .eq('status', 'checked_in');

    return jsonResponse({ ok: true, checked_in_count: count ?? 1 });
  } catch (error) {
    console.error('tournament-check-in error:', error);
    return errorResponse('Internal server error', 500);
  }
});
