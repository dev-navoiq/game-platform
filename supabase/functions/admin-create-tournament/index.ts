import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse, assertFields } from '../_shared/validation.ts';
import { requireAdmin } from '../_shared/admin.ts';

// Create an official tournament with full server-side control. Admin-gated;
// bypasses the organizer-insert RLS path used by the player app. The DB enums
// (game_type, tournament_format, subscription_tier, room_social_mode) are the
// final authority on categorical fields — an invalid value fails the insert.
const FORMATS = ['single_elimination', 'double_elimination', 'round_robin', 'swiss', 'multi_stage'];

// Server-authoritative tournament support (prompts/25 §T3): only games whose
// rules + outcome adapters exist server-side, per match shape. Spades/hearts/
// chess/rummy/sequence have no server rules yet; bridge's state builder
// requires exactly 4 players so it is team-play only.
const GAMES_1V1 = ['twenty_nine', 'oh_hell', 'ludo'];
const GAMES_2V2 = ['twenty_nine', 'bridge'];
// Random pairing needs partnership-agnostic play; bridge conventions rule it out.
const NO_SOLO_PAIRING = ['bridge'];

interface PrizeRow { place: number; coins?: number; gems?: number; skin_id?: string; title?: string; }

interface CreateRequest {
  name: string;
  description?: string;
  game_type: string;
  format: string;
  start_time: string;
  registration_start?: string;
  registration_end?: string;
  min_participants?: number;
  max_participants?: number;
  entry_fee_coins?: number;
  entry_fee_gems?: number;
  prize_pool?: PrizeRow[];
  settings?: Record<string, unknown>;
  min_subscription_tier?: string;
  room_social_mode?: string;
  is_official?: boolean;
  team_size?: number;
  allow_solo_pairing?: boolean;
}

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

    const body: CreateRequest = await req.json();

    const missing = assertFields(body as unknown as Record<string, unknown>, ['name', 'game_type', 'format', 'start_time']);
    if (missing) return errorResponse(missing, 400, 'MISSING_FIELD');
    if (!FORMATS.includes(body.format)) return errorResponse(`Unknown format ${body.format}`, 400, 'BAD_FORMAT');

    // ── Team shape + game allow-list ───────────────────────────────────────
    const teamSize = body.team_size ?? 1;
    if (teamSize !== 1 && teamSize !== 2) return errorResponse('team_size must be 1 or 2', 400, 'BAD_TEAM_SIZE');
    const allowedGames = teamSize === 2 ? GAMES_2V2 : GAMES_1V1;
    if (!allowedGames.includes(body.game_type)) {
      return errorResponse(
        `${body.game_type} is not supported for ${teamSize === 2 ? '2v2 team' : '1v1'} tournaments (supported: ${allowedGames.join(', ')})`,
        400, 'GAME_UNSUPPORTED',
      );
    }
    let allowSoloPairing = teamSize === 2 && (body.allow_solo_pairing ?? false);
    if (allowSoloPairing && NO_SOLO_PAIRING.includes(body.game_type)) {
      return errorResponse(`${body.game_type} tournaments are teams-only (no solo pairing)`, 400, 'TEAMS_ONLY');
    }

    // ── Capacity (counts PLAYERS; team tournaments need even, >= 2 teams) ──
    const minP = body.min_participants ?? 4;
    const maxP = body.max_participants ?? 32;
    if (minP < teamSize * 2) return errorResponse(`min_participants must be >= ${teamSize * 2}`, 400, 'BAD_CAPACITY');
    if (maxP < minP) return errorResponse('max_participants must be >= min_participants', 400, 'BAD_CAPACITY');
    if (teamSize === 2 && (minP % 2 !== 0 || maxP % 2 !== 0)) {
      return errorResponse('Team tournaments need even min/max participants', 400, 'BAD_CAPACITY');
    }

    // ── Fees ──────────────────────────────────────────────────────────────────
    const feeCoins = body.entry_fee_coins ?? 0;
    const feeGems = body.entry_fee_gems ?? 0;
    if (feeCoins < 0 || feeGems < 0) return errorResponse('Entry fees must be >= 0', 400, 'BAD_FEE');

    // ── Prize pool shape ──────────────────────────────────────────────────────
    const prizePool = body.prize_pool ?? [];
    if (!Array.isArray(prizePool)) return errorResponse('prize_pool must be an array', 400, 'BAD_PRIZE');
    for (const p of prizePool) {
      if (typeof p.place !== 'number' || p.place < 1) return errorResponse('Each prize needs a place >= 1', 400, 'BAD_PRIZE');
      if ((p.coins ?? 0) < 0 || (p.gems ?? 0) < 0) return errorResponse('Prize amounts must be >= 0', 400, 'BAD_PRIZE');
    }

    // ── Timing sanity ─────────────────────────────────────────────────────────
    if (Number.isNaN(Date.parse(body.start_time))) return errorResponse('start_time must be an ISO timestamp', 400, 'BAD_TIME');

    const insert: Record<string, unknown> = {
      name: body.name,
      description: body.description ?? null,
      game_type: body.game_type,
      format: body.format,
      is_official: body.is_official ?? true,
      organizer_id: null, // official tournaments have no player organizer
      start_time: body.start_time,
      registration_start: body.registration_start ?? null,
      registration_end: body.registration_end ?? null,
      min_participants: minP,
      max_participants: maxP,
      entry_fee_coins: feeCoins,
      entry_fee_gems: feeGems,
      prize_pool: prizePool,
      settings: body.settings ?? {},
      min_subscription_tier: body.min_subscription_tier ?? 'free',
      room_social_mode: body.room_social_mode ?? 'focus',
      status: 'registration',
      team_size: teamSize,
      allow_solo_pairing: allowSoloPairing,
    };

    const { data, error } = await admin
      .from('tournaments')
      .insert(insert)
      .select('*')
      .single();
    if (error) return errorResponse(`Insert failed: ${error.message}`, 400, 'INSERT_FAILED');

    return jsonResponse({ ok: true, tournament: data }, 201);
  } catch (error) {
    console.error('admin-create-tournament error:', error);
    return errorResponse('Internal server error', 500);
  }
});
