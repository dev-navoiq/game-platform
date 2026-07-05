import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { completeTournament } from '../_shared/tournament_report.ts';

interface CompleteRequest { tournament_id: string; }

// Completion normally fires automatically when the final match reports. This
// endpoint is an idempotent manual/admin re-run (organizer only).
serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: CompleteRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400);

    const { data: t } = await admin
      .from('tournaments').select('id, organizer_id').eq('id', body.tournament_id).single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if (t.organizer_id && t.organizer_id !== user.id) {
      return errorResponse('Only the organizer can complete this tournament', 403, 'NOT_ORGANIZER');
    }

    await completeTournament(admin, body.tournament_id);

    const { data: updated } = await admin
      .from('tournaments')
      .select('status, winner_id, final_standings')
      .eq('id', body.tournament_id).single();

    return jsonResponse({ ok: true, ...updated });
  } catch (error) {
    console.error('tournament-complete error:', error);
    return errorResponse('Internal server error', 500);
  }
});
