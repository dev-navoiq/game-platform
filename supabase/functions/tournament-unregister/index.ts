import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency } from '../_shared/currency.ts';

interface UnregisterRequest { tournament_id: string; }

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body: UnregisterRequest = await req.json();
    if (!body.tournament_id) return errorResponse('tournament_id is required', 400);

    const { data: t } = await admin
      .from('tournaments').select('id, status').eq('id', body.tournament_id).single();
    if (!t) return errorResponse('Tournament not found', 404, 'NOT_FOUND');
    if (t.status !== 'registration') return errorResponse('Cannot leave after start', 409, 'CANNOT_UNREGISTER');

    // Refund via the ledger (idempotent: only if not already refunded).
    const { data: ledger } = await admin
      .from('tournament_entry_ledger')
      .select('id, coins_paid, gems_paid, refunded')
      .eq('tournament_id', t.id).eq('user_id', user.id)
      .maybeSingle();

    if (ledger && !ledger.refunded) {
      const { data: flipped } = await admin
        .from('tournament_entry_ledger')
        .update({ refunded: true })
        .eq('id', ledger.id).eq('refunded', false)
        .select('id');
      if (flipped && flipped.length > 0) {
        if (ledger.coins_paid > 0) await creditCurrency(admin, user.id, 'coins', ledger.coins_paid, 'tournament_refund', t.id);
        if (ledger.gems_paid > 0) await creditCurrency(admin, user.id, 'gems', ledger.gems_paid, 'tournament_refund', t.id);
      }
    }

    await admin.from('tournament_participants')
      .delete().eq('tournament_id', t.id).eq('user_id', user.id);

    return jsonResponse({ ok: true });
  } catch (error) {
    console.error('tournament-unregister error:', error);
    return errorResponse('Internal server error', 500);
  }
});
