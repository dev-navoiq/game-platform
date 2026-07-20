import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { startTournament } from '../_shared/tournament_report.ts';

interface StartRequest { tournament_id: string; }

const ERROR_MESSAGES: Record<string, string> = {
  NOT_FOUND: 'Tournament not found',
  BAD_STATUS: 'Tournament cannot be started',
  FORMAT_UNSUPPORTED: 'Format not yet supported server-side',
  NOT_ENOUGH_PARTICIPANTS: 'Not enough participants',
  ALREADY_STARTING: 'Tournament is already starting',
};

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: StartRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400);

    // ── Organizer check (official/scheduled starts run via admin-force-start) ──
    const { data: t } = await admin
      .from('tournaments')
      .select('organizer_id')
      .eq('id', body.tournament_id)
      .single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if (t.organizer_id && t.organizer_id !== user.id) {
      return errorResponse('Only the organizer can start this tournament', 403, 'NOT_ORGANIZER');
    }

    const result = await startTournament(admin, body.tournament_id);
    if (result.status === 'error') {
      return errorResponse(ERROR_MESSAGES[result.code ?? ''] ?? 'Cannot start tournament', result.httpStatus ?? 400, result.code);
    }
    if (result.status === 'cancelled') {
      return jsonResponse({ ok: true, cancelled: true, reason: result.reason });
    }
    return jsonResponse({ ok: true, matches: result.matches, format: result.format });
  } catch (error) {
    console.error('tournament-start error:', error);
    return errorResponse('Internal server error', 500);
  }
});
