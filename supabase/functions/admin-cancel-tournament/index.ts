import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { requireAdmin } from '../_shared/admin.ts';
import { refundAllEntries } from '../_shared/tournament_report.ts';

// Cancel a tournament and refund every un-refunded entry. Admin-gated.
// Idempotent-ish: cancelling an already-cancelled/completed tournament is a
// no-op refund pass (refundAllEntries only touches refunded=false rows).
interface CancelRequest { tournament_id: string; }

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

    const body: CancelRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400, 'MISSING_FIELD');

    const { data: t } = await admin
      .from('tournaments')
      .select('id, status')
      .eq('id', body.tournament_id)
      .single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if (t.status === 'completed') return errorResponse('Cannot cancel a completed tournament', 409, 'BAD_STATUS');

    await refundAllEntries(admin, t.id);
    await admin.from('tournaments').update({ status: 'cancelled' }).eq('id', t.id);

    return jsonResponse({ ok: true, cancelled: true });
  } catch (error) {
    console.error('admin-cancel-tournament error:', error);
    return errorResponse('Internal server error', 500);
  }
});
