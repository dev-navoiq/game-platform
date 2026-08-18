// FCM HTTP v1 push sender with preference + quiet-hours filtering.
//
// Requires the FCM_SERVICE_ACCOUNT function secret: the full JSON of a
// Google service account with the "Firebase Cloud Messaging API" role
// (project_id, client_email, private_key are used). Without it, sendPush
// logs and no-ops so local dev works before credentials exist.

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type PushCategory =
  | 'game_invites'
  | 'friend_activity'
  | 'turn_reminders'
  | 'tournament_updates'
  | 'challenge_reminders'
  | 'season_events'
  | 'daily_bonus'
  | 'promotional'
  | 'system_updates'
  | 'chat_messages';

export interface PushContent {
  title: string;
  body: string;
  /** Deep-link route and any extra payload; values must be strings for FCM. */
  data?: Record<string, string>;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedToken: { value: string; expiresAt: number } | null = null;

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.value;
  }

  const encoder = new TextEncoder();
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(encoder.encode(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })));
  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`FCM token exchange failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  cachedToken = { value: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

/** Minutes-of-day for "HH:MM[:SS]" time strings from Postgres. */
function minutesOfDay(time: string): number {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
}

function inQuietHours(
  startTime: string,
  endTime: string,
  tzOffsetMin: number | null,
): boolean {
  if (tzOffsetMin === null || tzOffsetMin === undefined) {
    // Unknown device timezone: deliver rather than silently drop.
    return false;
  }
  const utc = new Date();
  const localMin =
    ((utc.getUTCHours() * 60 + utc.getUTCMinutes() + tzOffsetMin) % 1440 + 1440) % 1440;
  const start = minutesOfDay(startTime);
  const end = minutesOfDay(endTime);
  // Overnight ranges (e.g. 22:00 → 08:00) wrap midnight.
  return start <= end
    ? localMin >= start && localMin < end
    : localMin >= start || localMin < end;
}

export interface PushResult {
  sent: number;
  suppressed: number;
  prunedTokens: number;
}

/**
 * Send a push to each user in `userIds` who has `category` enabled and is
 * not inside their quiet hours. Prunes device tokens FCM reports as dead.
 */
export async function sendPush(
  admin: SupabaseClient,
  userIds: string[],
  category: PushCategory,
  content: PushContent,
): Promise<PushResult> {
  const result: PushResult = { sent: 0, suppressed: 0, prunedTokens: 0 };
  if (userIds.length === 0) return result;

  const saRaw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!saRaw) {
    console.warn('sendPush: FCM_SERVICE_ACCOUNT not set — skipping push send');
    return result;
  }
  const sa: ServiceAccount = JSON.parse(saRaw);

  const [{ data: prefs }, { data: profiles }] = await Promise.all([
    admin
      .from('notification_preferences')
      .select(`user_id, ${category}, quiet_hours_enabled, quiet_hours_start, quiet_hours_end`)
      .in('user_id', userIds),
    admin.from('profiles').select('id, tz_offset_min').in('id', userIds),
  ]);

  const offsetById = new Map<string, number | null>(
    (profiles ?? []).map((p: { id: string; tz_offset_min: number | null }) => [p.id, p.tz_offset_min]),
  );
  const prefsById = new Map<string, Record<string, unknown>>(
    (prefs ?? []).map((p: Record<string, unknown>) => [p.user_id as string, p]),
  );

  const recipients = userIds.filter((id) => {
    const p = prefsById.get(id);
    // Missing row = table defaults (everything but promotional on).
    if (p && p[category] === false) {
      result.suppressed++;
      return false;
    }
    if (
      p &&
      p.quiet_hours_enabled === true &&
      inQuietHours(p.quiet_hours_start as string, p.quiet_hours_end as string, offsetById.get(id) ?? null)
    ) {
      result.suppressed++;
      return false;
    }
    return true;
  });
  if (recipients.length === 0) return result;

  const { data: tokens } = await admin
    .from('device_push_tokens')
    .select('user_id, token')
    .in('user_id', recipients);
  if (!tokens || tokens.length === 0) return result;

  const accessToken = await getAccessToken(sa);
  const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  await Promise.all(tokens.map(async (row: { user_id: string; token: string }) => {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: row.token,
          notification: { title: content.title, body: content.body },
          data: { category, ...(content.data ?? {}) },
          android: {
            notification: { channel_id: 'gathr_default' },
          },
          apns: {
            payload: { aps: { sound: 'default' } },
          },
        },
      }),
    });

    if (res.ok) {
      result.sent++;
      return;
    }
    const errText = await res.text();
    // Dead token: uninstalled app or rotated registration. Prune it.
    if (res.status === 404 || errText.includes('UNREGISTERED')) {
      await admin
        .from('device_push_tokens')
        .delete()
        .eq('user_id', row.user_id)
        .eq('token', row.token);
      result.prunedTokens++;
    } else {
      console.error(`sendPush: FCM ${res.status} for user ${row.user_id}: ${errText}`);
    }
  }));

  return result;
}

/**
 * Diagnostic sender (#263): sends to EVERY token of one user, bypassing
 * pref/quiet-hour filtering, and returns the raw FCM outcome per token so
 * silent failures (SENDER_ID_MISMATCH, APNs config errors…) become visible.
 * Admin-gated caller only (admin-push-test).
 */
export async function sendPushDiagnostic(
  admin: SupabaseClient,
  userId: string,
  content: PushContent,
): Promise<Array<Record<string, unknown>>> {
  const saRaw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!saRaw) return [{ error: 'FCM_SERVICE_ACCOUNT not set' }];
  const sa: ServiceAccount = JSON.parse(saRaw);

  const { data: tokens } = await admin
    .from('device_push_tokens')
    .select('token, platform, updated_at')
    .eq('user_id', userId);
  if (!tokens || tokens.length === 0) return [{ error: 'no device tokens' }];

  const accessToken = await getAccessToken(sa);
  const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  const results: Array<Record<string, unknown>> = [];
  for (const row of tokens) {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: row.token,
          notification: { title: content.title, body: content.body },
          data: content.data ?? {},
          android: { notification: { channel_id: 'gathr_default' } },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    });
    const body = await res.text();
    results.push({
      token_prefix: (row.token as string).slice(0, 12),
      platform: row.platform,
      token_age: row.updated_at,
      fcm_status: res.status,
      fcm_response: body.slice(0, 400),
    });
  }
  return results;
}
