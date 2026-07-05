import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Returns true if the user is a guest (anonymous) account.
 * Guests live in the coin economy only; gems / gem tournaments / social / IAP
 * all require a registered account.
 */
export async function isGuest(admin: SupabaseClient, userId: string): Promise<boolean> {
  const { data } = await admin
    .from('profiles')
    .select('account_type')
    .eq('id', userId)
    .single();
  return (data?.account_type ?? 'registered') === 'guest';
}

/** Returns true if the user is a registered (non-guest) account. */
export async function isRegistered(admin: SupabaseClient, userId: string): Promise<boolean> {
  return !(await isGuest(admin, userId));
}
