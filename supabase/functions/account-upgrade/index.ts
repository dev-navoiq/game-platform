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

    // ── Shed the guest_ placeholder name (#57, owner-caught) ──────────────
    // Fresh signups derive a username from the email; the upgrade path kept
    // the guest_xxxxxx placeholder, so upgraded players still looked like
    // guests. Derive from the linked email, suffix on collision.
    const { data: prof } = await admin
      .from('profiles')
      .select('username')
      .eq('id', user.id)
      .single();
    const email = authUser?.user?.email;
    const metaName = ((authUser?.user?.user_metadata?.full_name ??
      authUser?.user?.user_metadata?.name ?? '') as string)
      .toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    if (prof?.username?.startsWith('guest_') && (email || metaName)) {
      // Prefer the provider-supplied name; never derive from an Apple
      // private-relay address (random noise). Mirrors handle_new_user.
      const fromEmail = email && !email.endsWith('@privaterelay.appleid.com')
        ? email.split('@')[0].toLowerCase().replace(/[^a-z0-9_]/g, '')
        : '';
      const base = (metaName || fromEmail || 'player').slice(0, 20);
      let candidate = base;
      for (let i = 0; i < 5; i++) {
        const { error: renameErr } = await admin
          .from('profiles')
          .update({ username: candidate })
          .eq('id', user.id);
        if (!renameErr) break;
        candidate = `${base}${Math.floor(Math.random() * 9000) + 1000}`;
      }
    }

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
