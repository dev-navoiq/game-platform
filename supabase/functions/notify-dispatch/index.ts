// Database-webhook target: pg_net triggers (see migration 20260707000000)
// POST here on social events, and this function fans out FCM pushes via
// _shared/push.ts. Auth is a shared secret, not a user JWT — config.toml
// sets verify_jwt=false for this function, and staging/prod must set the
// NOTIFY_WEBHOOK_SECRET function secret to match webhook_config.webhook_secret.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { jsonResponse, errorResponse } from '../_shared/validation.ts';
import { sendPush, PushCategory, PushContent } from '../_shared/push.ts';

interface WebhookPayload {
  event: 'dm' | 'friend_request' | 'friend_accepted';
  record: Record<string, unknown>;
}

async function username(admin: ReturnType<typeof getSupabaseAdmin>, userId: string): Promise<string> {
  const { data } = await admin
    .from('profiles')
    .select('display_name, username')
    .eq('id', userId)
    .maybeSingle();
  return (data?.display_name as string) || (data?.username as string) || 'A player';
}

/** Length-independent constant-accumulation compare (inputs already length-checked). */
function timingSafeEqual(a: string, b: string): boolean {
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  // Fail CLOSED: this endpoint is public (verify_jwt=false), so if the shared
  // secret is not configured we must reject every request rather than fall back
  // to a committed default that an attacker could read from the repo. See
  // SECURITY-AUDIT H2 / SECURITY-GUIDELINES E2.
  const secret = Deno.env.get('NOTIFY_WEBHOOK_SECRET');
  if (!secret) {
    console.error('notify-dispatch: NOTIFY_WEBHOOK_SECRET is not set; rejecting.');
    return errorResponse('Webhook not configured', 503, 'WEBHOOK_UNCONFIGURED');
  }
  const provided = req.headers.get('x-webhook-secret') ?? '';
  // Constant-time-ish comparison (length + char accumulation) to avoid leaking
  // the secret via response timing.
  if (provided.length !== secret.length ||
      !timingSafeEqual(provided, secret)) {
    return errorResponse('Unauthorized', 401);
  }

  try {
    const admin = getSupabaseAdmin();
    const { event, record }: WebhookPayload = await req.json();

    let targets: string[] = [];
    let category: PushCategory;
    let content: PushContent;

    switch (event) {
      case 'dm': {
        const senderId = record.sender_id as string;
        const recipientId = record.recipient_id as string;
        const messageType = record.message_type as string;
        // System messages accompany in-app flows that already notify.
        if (messageType === 'system') {
          return jsonResponse({ skipped: 'system_message' });
        }
        const sender = await username(admin, senderId);
        targets = [recipientId];
        if (messageType === 'game_invite') {
          category = 'game_invites';
          content = {
            title: sender,
            body: 'invited you to a game — tap to join',
            data: { route: `/messages/${senderId}` },
          };
        } else if (messageType === 'tournament_invite') {
          const payload = record.payload as Record<string, unknown> | null;
          const tournamentName = (payload?.name as string) ?? 'a tournament';
          const tournamentId = payload?.tournament_id as string | undefined;
          category = 'tournament_updates';
          content = {
            title: sender,
            body: `invited you to ${tournamentName} — tap to view`,
            data: {
              route: tournamentId
                ? `/tournament/${tournamentId}`
                : `/messages/${senderId}`,
            },
          };
        } else {
          category = 'chat_messages';
          const text = (record.content as string) ?? '';
          content = {
            title: sender,
            body: text.length > 140 ? `${text.slice(0, 139)}…` : text,
            data: { route: `/messages/${senderId}` },
          };
        }
        break;
      }

      case 'friend_request': {
        const requesterId = record.user_id as string;
        const requester = await username(admin, requesterId);
        targets = [record.friend_id as string];
        category = 'friend_activity';
        content = {
          title: 'New friend request',
          body: `${requester} wants to be your friend`,
          data: { route: '/friends' },
        };
        break;
      }

      case 'friend_accepted': {
        // friend_id accepted user_id's request → notify the original requester.
        const accepterId = record.friend_id as string;
        const accepter = await username(admin, accepterId);
        targets = [record.user_id as string];
        category = 'friend_activity';
        content = {
          title: 'Friend request accepted',
          body: `${accepter} accepted your friend request`,
          data: { route: '/friends' },
        };
        break;
      }

      default:
        return errorResponse(`Unknown event: ${event}`, 400);
    }

    const result = await sendPush(admin, targets, category, content);
    return jsonResponse({ event, ...result });
  } catch (error) {
    console.error('notify-dispatch error:', error);
    return errorResponse('Internal server error', 500);
  }
});
