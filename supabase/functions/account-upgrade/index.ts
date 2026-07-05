import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { creditCurrency } from '../_shared/currency.ts';
import { getEconomyConfig } from '../_shared/rewards.ts';

// Called by the app AFTER a native Supabase anonymous→permanent conversion
// (updateUser({email,password}) or linkIdentity({provider})). The user id is
// unchanged, so the profile (coins/XP/level) is already attached — this just
// flips account_type to 'registered' and grants the one-time welcome gems.
// Idempotent: safe to call more than once.
serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    // ── Verify the account is genuinely no longer anonymous ────────────────
    const { data: authUser } = await admin.auth.admin.getUserById(user.id);
    const stillAnonymous =
      authUser?.user?.is_anonymous === true &&
      !authUser?.user?.email &&
      (authUser?.user?.identities?.length ?? 0) === 0;
    if (stillAnonymous) {
      return errorResponse('Link an email or social identity first', 400, 'NOT_UPGRADED');
    }

    // ── Flip account_type to registered ────────────────────────────────────
    await admin
      .from('profiles')
      .update({ account_type: 'registered' })
      .eq('id', user.id);

    // ── Grant welcome gems once ────────────────────────────────────────────
    // Explicit pre-check: creditCurrency bumps the balance before writing the
    // ledger row and doesn't surface a unique-index violation, so we must gate
    // on an existing grant here (the unique index is a backstop).
    const config = await getEconomyConfig(admin);
    let welcomeGemsGranted = 0;
    let gemsBalance: number | null = null;
    if (config.welcome_gem_grant > 0) {
      const { data: prior } = await admin
        .from('currency_transactions')
        .select('id')
        .eq('user_id', user.id)
        .eq('reason', 'welcome_gem_grant')
        .maybeSingle();
      if (!prior) {
        const r = await creditCurrency(
          admin, user.id, 'gems', config.welcome_gem_grant,
          'welcome_gem_grant', user.id,
        );
        welcomeGemsGranted = config.welcome_gem_grant;
        gemsBalance = r.balance_after;
      }
    }

    return jsonResponse({
      account_type: 'registered',
      welcome_gems_granted: welcomeGemsGranted,
      gems_balance: gemsBalance,
    });
  } catch (error) {
    console.error('Account upgrade error:', error);
    return errorResponse('Internal server error', 500);
  }
});
