import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { requireAdmin } from '../_shared/admin.ts';
import { sendPushDiagnostic } from '../_shared/push.ts';

// #263 diagnostic: send a test push to every device token of one user and
// return the RAW per-token FCM outcome — makes silent delivery failures
// (SENDER_ID_MISMATCH, APNs auth problems, dead tokens) visible. Admin-only.
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

    const body = await req.json();
    let userId = body.user_id as string | undefined;
    if (!userId && body.email) {
      const { data } = await admin
        .from('profiles').select('id')
        .ilike('username', '%')  // placeholder; resolve via auth admin below
        .limit(0);
      void data;
      const { data: users } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
      userId = users?.users.find((u) => u.email === body.email)?.id;
    }
    if (!userId) return errorResponse('user_id or email required', 400, 'MISSING_FIELD');

    const results = await sendPushDiagnostic(admin, userId, {
      title: 'Gathr push test',
      body: `Diagnostic ${new Date().toISOString()}`,
      data: { route: '/home' },
    });
    return jsonResponse({ ok: true, results });
  } catch (e) {
    console.error('admin-push-test error:', e);
    return errorResponse('Internal server error', 500);
  }
});
