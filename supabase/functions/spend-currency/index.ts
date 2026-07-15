import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { debitCurrency } from '../_shared/currency.ts';

// Server-authoritative currency SPEND path.
//
// Once profiles.coins/gems are locked to service-role writes (see the security
// hardening migration), the client can no longer PATCH its own balance. All
// client-initiated spends (challenge reroll, season-pass purchase, shop buys)
// route through here. This function only ever DEBITS — a client-supplied amount
// is safe because a user can only reduce their own balance; the exploit we are
// closing is client-side CREDITING, which is impossible here.
//
// The reason is recorded verbatim on the ledger. We only forbid reasons that a
// reward idempotency guard keys on, so a spend can't collide with / poison a
// credit's uniqueness key. Otherwise any short reason string is fine — a debit
// can only shrink the caller's own balance, so it is not an abuse vector.

const RESERVED_REASONS = new Set<string>([
  'challenge_reward',
  'game_reward',
  'tournament_prize',
  'daily_bonus',
  'welcome_gem',
  'referral_reward',
]);

const MAX_SPEND = 1_000_000; // sanity ceiling; a single spend larger than this is a bug/abuse

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = getSupabaseClient(req);
    const admin = getSupabaseAdmin();
    const auth = await requireAuth(supabase);
    if (auth.error) return auth.error;
    const user = auth.user;

    const body = await req.json().catch(() => ({}));
    const currency = body.currency;
    const amount = body.amount;
    const reason = body.reason;
    const referenceId = body.reference_id as string | undefined;

    if (currency !== 'coins' && currency !== 'gems') {
      return errorResponse('currency must be "coins" or "gems"', 400, 'BAD_CURRENCY');
    }
    if (typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
      return errorResponse('amount must be a positive integer', 400, 'BAD_AMOUNT');
    }
    if (amount > MAX_SPEND) {
      return errorResponse('amount exceeds maximum', 400, 'AMOUNT_TOO_LARGE');
    }
    if (typeof reason !== 'string' || reason.length === 0 || reason.length > 64) {
      return errorResponse('reason must be a non-empty string (<=64 chars)', 400, 'BAD_REASON');
    }
    if (RESERVED_REASONS.has(reason)) {
      return errorResponse('reason is reserved for server-issued credits', 400, 'RESERVED_REASON');
    }

    // debitCurrency (service role) enforces sufficient balance and writes the
    // ledger row atomically; it throws on insufficient funds.
    let result;
    try {
      result = await debitCurrency(admin, user.id, currency, amount, reason, referenceId);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.startsWith('Insufficient')) {
        return errorResponse(msg, 400, 'INSUFFICIENT_FUNDS');
      }
      throw e;
    }

    return jsonResponse({
      currency,
      spent: amount,
      balance_after: result.balance_after,
    });
  } catch (error) {
    console.error('spend-currency error:', error);
    return errorResponse('Internal server error', 500);
  }
});
