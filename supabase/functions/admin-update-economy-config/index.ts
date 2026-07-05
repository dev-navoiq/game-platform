import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse } from '../_shared/validation.ts';
import { requireAdmin } from '../_shared/admin.ts';

// Live-edit the single-row economy_config (id = 1). Admin-gated. Accepts a
// partial patch — only the provided columns change. Ranges mirror the CHECK
// constraints in migration 20260702000000 so bad input fails fast with a clear
// message instead of a raw Postgres error.

// Integer columns that must be >= 0.
const NON_NEGATIVE_INTS = [
  'game_end_coins_win', 'game_end_coins_loss',
  'game_end_xp_win', 'game_end_xp_loss',
  'first_win_of_day_bonus', 'daily_coin_earn_cap', 'welcome_gem_grant',
];

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

    const body = await req.json() as Record<string, unknown>;
    const patch: Record<string, unknown> = {};

    // ── Non-negative integers ─────────────────────────────────────────────────
    for (const key of NON_NEGATIVE_INTS) {
      if (body[key] === undefined) continue;
      const v = body[key];
      if (!Number.isInteger(v) || (v as number) < 0) {
        return errorResponse(`${key} must be an integer >= 0`, 400, 'BAD_VALUE');
      }
      patch[key] = v;
    }

    // ── active_tournament_cap >= 1 ────────────────────────────────────────────
    if (body.active_tournament_cap !== undefined) {
      const v = body.active_tournament_cap;
      if (!Number.isInteger(v) || (v as number) < 1) {
        return errorResponse('active_tournament_cap must be an integer >= 1', 400, 'BAD_VALUE');
      }
      patch.active_tournament_cap = v;
    }

    // ── rake_percent_default in [0, 100] ──────────────────────────────────────
    if (body.rake_percent_default !== undefined) {
      const v = body.rake_percent_default;
      if (typeof v !== 'number' || Number.isNaN(v) || v < 0 || v > 100) {
        return errorResponse('rake_percent_default must be a number in [0, 100]', 400, 'BAD_VALUE');
      }
      patch.rake_percent_default = v;
    }

    // ── tier_earn_multiplier: { tier: number >= 0 } ───────────────────────────
    if (body.tier_earn_multiplier !== undefined) {
      const m = body.tier_earn_multiplier;
      if (typeof m !== 'object' || m === null || Array.isArray(m)) {
        return errorResponse('tier_earn_multiplier must be an object', 400, 'BAD_VALUE');
      }
      for (const [tier, mult] of Object.entries(m as Record<string, unknown>)) {
        if (typeof mult !== 'number' || Number.isNaN(mult) || mult < 0) {
          return errorResponse(`tier_earn_multiplier.${tier} must be a number >= 0`, 400, 'BAD_VALUE');
        }
      }
      patch.tier_earn_multiplier = m;
    }

    if (Object.keys(patch).length === 0) {
      return errorResponse('No valid fields to update', 400, 'EMPTY_PATCH');
    }

    const { data, error } = await admin
      .from('economy_config')
      .update(patch)
      .eq('id', 1)
      .select('*')
      .single();
    if (error) return errorResponse(`Update failed: ${error.message}`, 400, 'UPDATE_FAILED');

    return jsonResponse({ ok: true, config: data });
  } catch (error) {
    console.error('admin-update-economy-config error:', error);
    return errorResponse('Internal server error', 500);
  }
});
