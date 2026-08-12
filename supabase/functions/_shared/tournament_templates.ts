import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ─────────────────────────────────────────────────────────────────────────────
// Tournament recurrence templates (#251/#252, Epic #250 Phase 1).
//
// Clock templates (daily/weekly) are materialized by tournament-tick once the
// next occurrence enters the registration lead window. Sit&go templates keep
// exactly one open instance alive: spawned instantly on fill-start by
// tournament-register, with tournament-tick as the backstop (first spawn for
// a new template + self-heal if the instant path ever failed).
//
// Uniqueness anchors (migration 20260811000000):
//   uq_tournament_template_instance (template_id, start_time)
//   uq_tournament_template_open     (template_id) WHERE status='registration'
// Racing spawners lose with 23505 and must treat it as success-by-other.
// ─────────────────────────────────────────────────────────────────────────────

export interface TournamentTemplate {
  id: string;
  name: string;
  description: string | null;
  game_type: string;
  format: string;
  min_participants: number;
  max_participants: number;
  entry_fee_coins: number;
  entry_fee_gems: number;
  prize_pool: unknown;
  settings: Record<string, unknown> | null;
  team_size: number | null;
  allow_solo_pairing: boolean | null;
  rake_percent: number | null;
  room_social_mode: string | null;
  min_subscription_tier: string | null;
  check_in_minutes: number;
  schedule_kind: 'daily' | 'weekly' | 'sitgo';
  start_hhmm: string | null;
  weekday: number | null;
  tz_offset_min: number;
  registration_lead_minutes: number;
  active: boolean;
}

/** Sit&go instances start on fill, never by clock — park start_time on a
 *  far horizon so due-start/auto-cancel leave them alone, and each respawn
 *  gets a distinct (template_id, start_time). */
const SITGO_HORIZON_MS = 7 * 24 * 3_600_000;

/**
 * Next occurrence (UTC ms) of a clock-driven template at/after `nowMs`.
 * Template times are template-local via a fixed UTC offset (no DST — see
 * migration 20260811000000).
 */
export function nextTemplateStartMs(
  t: Pick<TournamentTemplate, 'schedule_kind' | 'start_hhmm' | 'weekday' | 'tz_offset_min'>,
  nowMs: number,
): number | null {
  if (t.schedule_kind === 'sitgo' || !t.start_hhmm) return null;
  const [hh, mm] = t.start_hhmm.split(':').map(Number);
  const offsetMs = t.tz_offset_min * 60_000;

  // Work in template-local time: local = utc + offset.
  const local = new Date(nowMs + offsetMs);
  const candidate = Date.UTC(
    local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate(), hh, mm);

  let startLocalMs = candidate;
  if (t.schedule_kind === 'daily') {
    if (startLocalMs <= local.getTime()) startLocalMs += 24 * 3_600_000;
  } else {
    // weekly: advance to the template's weekday (0=Sunday, local).
    const wd = local.getUTCDay();
    let deltaDays = ((t.weekday ?? 0) - wd + 7) % 7;
    if (deltaDays === 0 && startLocalMs <= local.getTime()) deltaDays = 7;
    startLocalMs += deltaDays * 24 * 3_600_000;
  }
  return startLocalMs - offsetMs; // back to UTC
}

/**
 * Create one instance of a template. For clock templates pass the computed
 * occurrence start; for sit&gos the horizon start is derived here.
 * Returns 'created' | 'exists' (unique-index race/idempotent) | 'error'.
 */
export async function spawnTemplateInstance(
  admin: SupabaseClient,
  t: TournamentTemplate,
  startIso?: string,
): Promise<'created' | 'exists' | 'error'> {
  const nowIso = new Date().toISOString();
  const isSitgo = t.schedule_kind === 'sitgo';
  const start = startIso ?? new Date(Date.now() + SITGO_HORIZON_MS).toISOString();

  // Rake must be on the row from birth: startTournament re-snapshots it at
  // start anyway (authoritative for payout), but pre-start the card computes
  // the pool projection from this row — an unset rake displayed "0% rake"
  // and over-promised the pool (user-caught, 2026-08-12).
  let rakePercent = t.rake_percent;
  if (rakePercent == null) {
    const { data: cfg } = await admin
      .from('economy_config')
      .select('rake_percent_default')
      .eq('id', 1)
      .single();
    rakePercent = (cfg?.rake_percent_default as number | null) ?? 10;
  }

  // Scheduled events keep their appointment — filling early must not start
  // them early (product decision 2026-08-11). Sit&gos are the opposite: the
  // fill IS the start. Template settings may override either default.
  const settingsDefaults = isSitgo
    ? { auto_start_when_full: true }
    : { auto_start_when_full: false };

  const { error } = await admin.from('tournaments').insert({
    name: t.name,
    description: t.description,
    game_type: t.game_type,
    format: t.format,
    is_official: true,
    registration_start: nowIso,
    registration_end: start,
    start_time: start,
    min_participants: t.min_participants,
    max_participants: t.max_participants,
    entry_fee_coins: t.entry_fee_coins,
    entry_fee_gems: t.entry_fee_gems,
    prize_pool: t.prize_pool,
    settings: { ...settingsDefaults, ...(t.settings ?? {}) },
    status: 'registration',
    template_id: t.id,
    check_in_minutes: t.check_in_minutes,
    ...(t.team_size != null ? { team_size: t.team_size } : {}),
    ...(t.allow_solo_pairing != null ? { allow_solo_pairing: t.allow_solo_pairing } : {}),
    rake_percent: rakePercent,
    ...(t.room_social_mode != null ? { room_social_mode: t.room_social_mode } : {}),
    ...(t.min_subscription_tier != null ? { min_subscription_tier: t.min_subscription_tier } : {}),
  });

  if (!error) return 'created';
  if (error.code === '23505') return 'exists';
  console.error(`spawnTemplateInstance failed for template ${t.id}:`, error);
  await admin.from('tournament_templates')
    .update({ last_error: `${nowIso}: ${error.message}` })
    .eq('id', t.id);
  return 'error';
}
