import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { errorResponse } from './validation.ts';

/**
 * Returns true if the user is on the admin allow-list (admin_users table).
 * Membership is managed out-of-band (migration seed / service-role insert).
 */
export async function isAdmin(admin: SupabaseClient, userId: string): Promise<boolean> {
  const { data } = await admin
    .from('admin_users')
    .select('user_id')
    .eq('user_id', userId)
    .maybeSingle();
  return !!data;
}

/**
 * Admin gate for edge functions. Returns a 403 Response if the user is not an
 * admin, otherwise null. Use after requireAuth:
 *
 *   const denied = await requireAdmin(admin, user.id);
 *   if (denied) return denied;
 */
export async function requireAdmin(
  admin: SupabaseClient,
  userId: string,
): Promise<Response | null> {
  if (await isAdmin(admin, userId)) return null;
  return errorResponse('Admin access required', 403, 'NOT_ADMIN');
}
