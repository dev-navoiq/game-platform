import { GameType } from './types.ts';
import { buildInitialState, initialDbPhase } from './game_setup.ts';
import { getSupabaseAdmin } from './supabase.ts';

type Admin = ReturnType<typeof getSupabaseAdmin>;

interface RoomRow {
  id: string;
  game_type: string;
  social_mode: string;
  code?: string;
  config?: Record<string, unknown> | null;
}

export type StartRoomResult =
  | { error: string; error_code: string }
  | { state: Record<string, unknown>; phase: string };

/**
 * Start a waiting room's game session: merge seated humans with config
 * bots, build the initial state, flip the room to 'playing', and mark all
 * players in-game.
 *
 * Shared by start-game (host button) and join-room (auto_start_when_full);
 * callers own authorization and the room-status precondition.
 */
export async function startRoomSession(
  admin: Admin,
  room: RoomRow,
): Promise<StartRoomResult> {
  const { data: players } = await admin
    .from('room_players')
    .select('*')
    .eq('room_id', room.id)
    .eq('is_spectator', false)
    .order('seat_index', { ascending: true });

  const bots: { id: string; difficulty: string; seat_index: number }[] =
    (room.config?.bots as { id: string; difficulty: string; seat_index: number }[]) ?? [];
  const humanIds = (players ?? []).map((p: { user_id: string }) => p.user_id);
  const playerIds = [...humanIds, ...bots.map((b) => b.id)];

  if (playerIds.length < 2) {
    return { error: 'Not enough players', error_code: 'NOT_ENOUGH_PLAYERS' };
  }

  const dealerIndex = Math.floor(Math.random() * playerIds.length);
  const stateData = buildInitialState(
    room.game_type as GameType,
    playerIds,
    dealerIndex,
    room.social_mode,
    room.config ?? undefined,
  );
  const dbPhase = initialDbPhase(stateData);

  const { error: roomUpdateErr } = await admin
    .from('game_rooms')
    .update({ status: 'playing' })
    .eq('id', room.id);
  if (roomUpdateErr) throw roomUpdateErr;

  const { data: updatedState, error: stateErr } = await admin
    .from('game_states')
    .update({
      phase: dbPhase,
      state_data: stateData,
      round: 1,
    })
    .eq('room_id', room.id)
    .select();
  if (stateErr) throw stateErr;
  if (!updatedState || updatedState.length === 0) {
    return { error: 'Game state not found for room', error_code: 'STATE_NOT_FOUND' };
  }

  for (const pid of playerIds) {
    await admin
      .from('profiles')
      .update({
        current_activity: {
          type: 'in_game',
          game_type: room.game_type,
          room_id: room.id,
          room_code: room.code,
          spectatable: true,
          joinable: false,
        },
      })
      .eq('id', pid);
  }

  return { state: stateData, phase: dbPhase };
}
