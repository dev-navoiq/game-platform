import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { requireAdmin } from '../_shared/admin.ts';
import { startTournament } from '../_shared/tournament_report.ts';

// Force-start a tournament regardless of organizer. Admin-gated thin wrapper
// over the shared startTournament core (same path organizer starts use).
interface ForceStartRequest { tournament_id: string; }

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

    const denied = await requireAdmin(admin, auth.user.id);
    if (denied) return denied;

    const body: ForceStartRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400, 'MISSING_FIELD');

    const result = await startTournament(admin, body.tournament_id);
    if (result.status === 'error') {
      return errorResponse(ERROR_MESSAGES[result.code ?? ''] ?? 'Cannot start tournament', result.httpStatus ?? 400, result.code);
    }
    if (result.status === 'cancelled') {
      return jsonResponse({ ok: true, cancelled: true, reason: result.reason });
    }
    return jsonResponse({ ok: true, matches: result.matches, format: result.format });
  } catch (error) {
    console.error('admin-force-start-tournament error:', error);
    return errorResponse('Internal server error', 500);
  }
});
