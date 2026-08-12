import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { getSupabaseClient, getSupabaseAdmin } from '../_shared/supabase.ts';
import { requireAuth, jsonResponse, errorResponse, assertFields } from '../_shared/validation.ts';
import { requireAdmin } from '../_shared/admin.ts';

// Admin CRUD for tournament recurrence templates (#253, Epic #250 Phase 1).
// Templates drive tournament-tick's materializer (clock kinds) and the
// sit&go respawn loop — see _shared/tournament_templates.ts. Edits apply to
// FUTURE instances only (already-materialized rows are ordinary tournaments
// and stay as created).
//
// Actions: { action: 'list' } | { action: 'create', template: {...} }
//        | { action: 'update', id, patch: {...} }   (pause = patch.active=false)

const FORMATS = ['single_elimination', 'double_elimination', 'round_robin', 'swiss', 'multi_stage'];
const GAMES_1V1 = ['twenty_nine', 'oh_hell', 'ludo'];
const GAMES_2V2 = ['twenty_nine', 'bridge'];
const KINDS = ['daily', 'weekly', 'sitgo'];

// Only these fields may be written by the console (create or patch).
const WRITABLE = [
  'name', 'description', 'game_type', 'format',
  'min_participants', 'max_participants', 'entry_fee_coins', 'entry_fee_gems',
  'prize_pool', 'settings', 'team_size', 'allow_solo_pairing', 'rake_percent',
  'room_social_mode', 'min_subscription_tier', 'check_in_minutes',
  'schedule_kind', 'start_hhmm', 'weekday', 'tz_offset_min',
  'registration_lead_minutes', 'active',
] as const;

function pickWritable(src: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of WRITABLE) if (src[k] !== undefined) out[k] = src[k];
  return out;
}

/** Shared shape checks for create + update payloads (fields that are present). */
function validate(t: Record<string, unknown>): string | null {
  if (t.format !== undefined && !FORMATS.includes(t.format as string)) return `Unknown format ${t.format}`;
  if (t.schedule_kind !== undefined && !KINDS.includes(t.schedule_kind as string)) return `Unknown schedule_kind ${t.schedule_kind}`;
  if (t.start_hhmm !== undefined && t.start_hhmm !== null && !/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(t.start_hhmm as string)) {
    return 'start_hhmm must be HH:MM (24h)';
  }
  if (t.weekday !== undefined && t.weekday !== null) {
    const w = t.weekday as number;
    if (!Number.isInteger(w) || w < 0 || w > 6) return 'weekday must be 0-6 (0=Sunday)';
  }
  const teamSize = (t.team_size as number | undefined) ?? 1;
  if (t.team_size !== undefined && teamSize !== 1 && teamSize !== 2) return 'team_size must be 1 or 2';
  if (t.game_type !== undefined) {
    const allowed = teamSize === 2 ? GAMES_2V2 : GAMES_1V1;
    if (!allowed.includes(t.game_type as string)) {
      return `${t.game_type} not supported for ${teamSize === 2 ? '2v2' : '1v1'} (supported: ${allowed.join(', ')})`;
    }
  }
  for (const k of ['min_participants', 'max_participants', 'entry_fee_coins', 'entry_fee_gems', 'check_in_minutes', 'registration_lead_minutes'] as const) {
    if (t[k] !== undefined && (!Number.isInteger(t[k]) || (t[k] as number) < 0)) return `${k} must be a non-negative integer`;
  }
  return null;
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

    const body = await req.json();

    if (body.action === 'list') {
      const { data, error } = await admin
        .from('tournament_templates')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) return errorResponse(`List failed: ${error.message}`, 400, 'LIST_FAILED');

      // Attach each template's open/most-recent instance for the console.
      const ids = (data ?? []).map((t) => t.id);
      const { data: instances } = ids.length
        ? await admin
            .from('tournaments')
            .select('id, template_id, status, current_participants, max_participants, start_time')
            .in('template_id', ids)
            .order('created_at', { ascending: false })
        : { data: [] };
      const latestByTemplate: Record<string, unknown> = {};
      for (const i of instances ?? []) {
        if (!(i.template_id in latestByTemplate)) latestByTemplate[i.template_id] = i;
      }
      return jsonResponse({
        ok: true,
        templates: (data ?? []).map((t) => ({ ...t, latest_instance: latestByTemplate[t.id] ?? null })),
      });
    }

    if (body.action === 'create') {
      const t = pickWritable(body.template ?? {});
      const missing = assertFields(t, ['name', 'game_type', 'schedule_kind']);
      if (missing) return errorResponse(missing, 400, 'MISSING_FIELD');
      if (t.schedule_kind !== 'sitgo' && !t.start_hhmm) {
        return errorResponse('daily/weekly templates need start_hhmm', 400, 'MISSING_FIELD');
      }
      if (t.schedule_kind === 'weekly' && (t.weekday === undefined || t.weekday === null)) {
        return errorResponse('weekly templates need weekday (0=Sunday)', 400, 'MISSING_FIELD');
      }
      const bad = validate(t);
      if (bad) return errorResponse(bad, 400, 'BAD_TEMPLATE');

      const { data, error } = await admin
        .from('tournament_templates')
        .insert(t)
        .select('*')
        .single();
      if (error) return errorResponse(`Create failed: ${error.message}`, 400, 'CREATE_FAILED');
      return jsonResponse({ ok: true, template: data }, 201);
    }

    if (body.action === 'update') {
      if (!body.id) return errorResponse('id is required', 400, 'MISSING_FIELD');
      const patch = pickWritable(body.patch ?? {});
      if (Object.keys(patch).length === 0) return errorResponse('patch is empty', 400, 'EMPTY_PATCH');
      const bad = validate(patch);
      if (bad) return errorResponse(bad, 400, 'BAD_TEMPLATE');

      const { data, error } = await admin
        .from('tournament_templates')
        .update({ ...patch, updated_at: new Date().toISOString() })
        .eq('id', body.id)
        .select('*')
        .single();
      if (error) return errorResponse(`Update failed: ${error.message}`, 400, 'UPDATE_FAILED');
      return jsonResponse({ ok: true, template: data });
    }

    return errorResponse(`Unknown action ${body.action}`, 400, 'BAD_ACTION');
  } catch (error) {
    console.error('admin-manage-template error:', error);
    return errorResponse('Internal server error', 500);
  }
});
