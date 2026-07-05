import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { creditCurrency } from './currency.ts';
import { getEconomyConfig } from './rewards.ts';
import { computeOutcomes } from './game_outcome.ts';
import { buildInitialState, initialDbPhase } from './game_setup.ts';
import {
  generateSingleElimination,
  generateRoundRobin,
  generateSwissFirstRound,
  generateSwissNextRound,
  recommendedSwissRounds,
  pairingKey,
  PlannedMatch,
  SwissStanding,
} from './bracket.ts';

const WIN_POINTS = 3;
const DRAW_POINTS = 1;

export const SUPPORTED_START_FORMATS = ['single_elimination', 'round_robin', 'swiss'];

export interface StartResult {
  status: 'started' | 'cancelled' | 'error';
  matches?: number;
  format?: string;
  reason?: string;
  code?: string;
  httpStatus?: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// startTournament — seed participants, snapshot rake, generate + insert the
// bracket, go live, and open round-1 rooms. This is the privileged core shared
// by the organizer-facing `tournament-start` function and `admin-force-start-
// tournament`; callers own their own authorization (organizer check / admin
// gate) before invoking. Insufficient participants → cancel + refund all.
// ─────────────────────────────────────────────────────────────────────────────
export async function startTournament(
  admin: SupabaseClient,
  tournamentId: string,
): Promise<StartResult> {
  const { data: t } = await admin
    .from('tournaments')
    .select('id, status, format, min_participants, current_participants')
    .eq('id', tournamentId)
    .single();
  if (!t) return { status: 'error', code: 'NOT_FOUND', httpStatus: 404 };

  if (t.status !== 'registration' && t.status !== 'starting') {
    return { status: 'error', code: 'BAD_STATUS', httpStatus: 409 };
  }
  if (!SUPPORTED_START_FORMATS.includes(t.format)) {
    return { status: 'error', code: 'FORMAT_UNSUPPORTED', httpStatus: 400 };
  }

  // ── Insufficient participants → cancel + refund all ──────────────────────
  if (t.current_participants < t.min_participants) {
    await refundAllEntries(admin, t.id);
    await admin.from('tournaments').update({ status: 'cancelled' }).eq('id', t.id);
    return { status: 'cancelled', reason: 'insufficient_participants' };
  }

  // ── Snapshot rake ────────────────────────────────────────────────────────
  const config = await getEconomyConfig(admin);
  await admin.from('tournaments').update({ rake_percent: config.rake_percent_default }).eq('id', t.id);

  // ── Seed participants: by level desc, random tiebreak ────────────────────
  const { data: participants } = await admin
    .from('tournament_participants')
    .select('user_id, profiles!inner(level)')
    .eq('tournament_id', t.id);
  if (!participants || participants.length < 2) {
    return { status: 'error', code: 'NOT_ENOUGH_PARTICIPANTS', httpStatus: 409 };
  }

  const ranked = participants
    .map((p) => ({
      userId: p.user_id as string,
      level: (p.profiles as unknown as { level: number }).level ?? 1,
      rand: crypto.getRandomValues(new Uint32Array(1))[0],
    }))
    .sort((a, b) => b.level - a.level || a.rand - b.rand);

  const ids = ranked.map((r) => r.userId);
  const seeds = ranked.map((_, i) => i + 1);

  // Persist seed + activate.
  for (let i = 0; i < ranked.length; i++) {
    await admin.from('tournament_participants')
      .update({ seed: i + 1, status: 'active' })
      .eq('tournament_id', t.id).eq('user_id', ranked[i].userId);
  }

  // ── Generate + insert bracket ────────────────────────────────────────────
  let planned: PlannedMatch[];
  if (t.format === 'single_elimination') planned = generateSingleElimination(ids, seeds);
  else if (t.format === 'round_robin') planned = generateRoundRobin(ids);
  else planned = generateSwissFirstRound(ids, seeds); // swiss

  await insertPlannedMatches(admin, t.id, planned);

  // ── Go live + create rooms for round-1 ready matches ─────────────────────
  await admin.from('tournaments').update({ status: 'in_progress' }).eq('id', t.id);
  await autoStartReadyMatches(admin, t.id);

  return { status: 'started', matches: planned.length, format: t.format };
}

function genRoomCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => chars[b % chars.length]).join('');
}

// ─────────────────────────────────────────────────────────────────────────────
// startTournamentMatch — turn a 'ready' match into a live 2-player game room.
// Idempotent: if the match already has a room, returns it.
// ─────────────────────────────────────────────────────────────────────────────
export async function startTournamentMatch(
  admin: SupabaseClient,
  matchId: string,
): Promise<{ room_id: string } | null> {
  const { data: match } = await admin
    .from('tournament_matches')
    .select('id, tournament_id, player1_id, player2_id, status, room_id')
    .eq('id', matchId)
    .single();
  if (!match) return null;

  if (match.room_id) return { room_id: match.room_id };
  if (match.status !== 'ready') return null;
  if (!match.player1_id || !match.player2_id) return null;

  const { data: tournament } = await admin
    .from('tournaments')
    .select('game_type, room_social_mode')
    .eq('id', match.tournament_id)
    .single();
  if (!tournament) return null;

  const playerIds = [match.player1_id, match.player2_id];
  const socialMode = tournament.room_social_mode ?? 'focus';

  // Create the room (server-owned; skips create-room's private-room limits).
  const { data: newRoom, error: roomErr } = await admin
    .from('game_rooms')
    .insert({
      code: genRoomCode(),
      game_type: tournament.game_type,
      status: 'playing',
      social_mode: socialMode,
      created_by: match.player1_id,
      max_players: 2,
      current_players: 2,
      is_private: true,
      config: { tournament_id: match.tournament_id, tournament_match_id: matchId },
    })
    .select('id, code')
    .single();
  if (roomErr || !newRoom) throw new Error(`tournament room create failed: ${roomErr?.message}`);

  // Seat the two players (1v1 => no teams).
  await admin.from('room_players').insert([
    { room_id: newRoom.id, user_id: match.player1_id, seat_index: 0, is_spectator: false },
    { room_id: newRoom.id, user_id: match.player2_id, seat_index: 1, is_spectator: false },
  ]);

  // Build the authoritative initial state and create the game_states row.
  const dealerIndex = crypto.getRandomValues(new Uint8Array(1))[0] % 2;
  const state = buildInitialState(tournament.game_type, playerIds, dealerIndex, socialMode);
  await admin.from('game_states').insert({
    room_id: newRoom.id,
    phase: initialDbPhase(state),
    state_data: state,
    round: 1,
  });

  await admin
    .from('tournament_matches')
    .update({ room_id: newRoom.id, status: 'in_progress', started_at: new Date().toISOString() })
    .eq('id', matchId);

  // Presence
  for (const pid of playerIds) {
    await admin.from('profiles').update({
      current_activity: {
        type: 'in_game', game_type: tournament.game_type,
        room_id: newRoom.id, room_code: newRoom.code, spectatable: true, joinable: false,
      },
    }).eq('id', pid);
  }

  return { room_id: newRoom.id };
}

// ─────────────────────────────────────────────────────────────────────────────
// reportTournamentMatchResult — called from validate-move's game-end block.
// No-op unless the room is a tournament match. Records the result, advances the
// bracket, and triggers completion at the end.
// ─────────────────────────────────────────────────────────────────────────────
export async function reportTournamentMatchResult(
  admin: SupabaseClient,
  roomId: string,
): Promise<void> {
  const { data: room } = await admin
    .from('game_rooms')
    .select('config, game_type')
    .eq('id', roomId)
    .single();
  const matchId = (room?.config as Record<string, unknown> | null)?.tournament_match_id as string | undefined;
  if (!matchId) return; // not a tournament room

  const { data: match } = await admin
    .from('tournament_matches')
    .select('*')
    .eq('id', matchId)
    .single();
  if (!match || match.status === 'completed') return; // idempotent

  const { data: gameState } = await admin
    .from('game_states')
    .select('state_data')
    .eq('room_id', roomId)
    .single();
  if (!gameState) return;

  const outcomes = computeOutcomes(room!.game_type, gameState.state_data as Record<string, unknown>);
  const p1 = match.player1_id as string;
  const p2 = match.player2_id as string;
  const o1 = outcomes.find((o) => o.user_id === p1);
  const o2 = outcomes.find((o) => o.user_id === p2);

  // Resolve winner (tiebreak draws by better seed = lower seed number).
  let winnerId: string;
  let isDraw = false;
  if (o1 && o2 && o1.result === 'draw' && o2.result === 'draw') {
    isDraw = true;
    const s1 = match.player1_seed ?? 9999;
    const s2 = match.player2_seed ?? 9999;
    winnerId = s1 <= s2 ? p1 : p2;
  } else if (o1?.result === 'win') {
    winnerId = p1;
  } else if (o2?.result === 'win') {
    winnerId = p2;
  } else {
    winnerId = (o1?.position ?? 99) <= (o2?.position ?? 99) ? p1 : p2;
  }
  const loserId = winnerId === p1 ? p2 : p1;

  await admin.from('tournament_matches').update({
    winner_id: winnerId,
    player1_score: o1?.points ?? 0,
    player2_score: o2?.points ?? 0,
    result_details: { outcomes, draw: isDraw },
    status: 'completed',
    completed_at: new Date().toISOString(),
  }).eq('id', matchId);

  const { data: tournament } = await admin
    .from('tournaments')
    .select('id, format')
    .eq('id', match.tournament_id)
    .single();
  const format = tournament?.format as string;
  const isElim = format === 'single_elimination' || format === 'double_elimination';

  // Update participant standings.
  await bumpParticipant(admin, match.tournament_id, winnerId, { win: true, draw: isDraw });
  await bumpParticipant(admin, match.tournament_id, loserId, { win: false, draw: isDraw, eliminate: isElim && !isDraw });

  // Advance winner into the next match (elimination brackets).
  if (match.next_match_id && match.next_match_slot) {
    await advanceInto(admin, match.next_match_id, match.next_match_slot, winnerId);
  }

  // Progress / completion.
  await checkTournamentProgress(admin, match.tournament_id, format);
}

async function bumpParticipant(
  admin: SupabaseClient,
  tournamentId: string,
  userId: string,
  opts: { win: boolean; draw: boolean; eliminate?: boolean },
): Promise<void> {
  const { data: p } = await admin
    .from('tournament_participants')
    .select('id, wins, losses, draws, points')
    .eq('tournament_id', tournamentId)
    .eq('user_id', userId)
    .maybeSingle();
  if (!p) return;

  const update: Record<string, unknown> = {};
  if (opts.draw) {
    update.draws = (p.draws ?? 0) + 1;
    update.points = (p.points ?? 0) + DRAW_POINTS;
  } else if (opts.win) {
    update.wins = (p.wins ?? 0) + 1;
    update.points = (p.points ?? 0) + WIN_POINTS;
  } else {
    update.losses = (p.losses ?? 0) + 1;
  }
  if (opts.eliminate) {
    update.status = 'eliminated';
    update.eliminated_at = new Date().toISOString();
  }
  await admin.from('tournament_participants').update(update).eq('id', p.id);
}

async function advanceInto(
  admin: SupabaseClient,
  nextMatchId: string,
  slot: number,
  playerId: string,
): Promise<void> {
  const col = slot === 1 ? 'player1_id' : 'player2_id';
  await admin.from('tournament_matches').update({ [col]: playerId }).eq('id', nextMatchId);

  // If both slots now filled, mark ready and start it.
  const { data: nm } = await admin
    .from('tournament_matches')
    .select('id, player1_id, player2_id, status')
    .eq('id', nextMatchId)
    .single();
  if (nm && nm.player1_id && nm.player2_id && nm.status === 'pending') {
    await admin.from('tournament_matches').update({ status: 'ready' }).eq('id', nextMatchId);
    await startTournamentMatch(admin, nextMatchId);
  }
}

async function checkTournamentProgress(
  admin: SupabaseClient,
  tournamentId: string,
  format: string,
): Promise<void> {
  const { data: matches } = await admin
    .from('tournament_matches')
    .select('id, round, status, next_match_id')
    .eq('tournament_id', tournamentId);
  if (!matches) return;

  const outstanding = matches.filter((m) => m.status !== 'completed' && m.status !== 'bye');

  if (format === 'single_elimination' || format === 'double_elimination') {
    // Final = a completed match with no next_match_id. Complete when none left.
    if (outstanding.length === 0) await completeTournament(admin, tournamentId);
    return;
  }

  if (format === 'round_robin') {
    if (outstanding.length === 0) await completeTournament(admin, tournamentId);
    return;
  }

  if (format === 'swiss') {
    // If the current (max) round is fully played, either pair the next round or finish.
    const maxRound = Math.max(...matches.map((m) => m.round));
    const roundDone = matches
      .filter((m) => m.round === maxRound)
      .every((m) => m.status === 'completed' || m.status === 'bye');
    if (!roundDone) return;

    const { count } = await admin
      .from('tournament_participants')
      .select('*', { count: 'exact', head: true })
      .eq('tournament_id', tournamentId);
    const rounds = recommendedSwissRounds(count ?? 2);
    if (maxRound >= rounds) {
      await completeTournament(admin, tournamentId);
    } else {
      await generateNextSwissRound(admin, tournamentId, maxRound + 1, matches);
    }
    return;
  }

  // Unknown format: complete when nothing is outstanding.
  if (outstanding.length === 0) await completeTournament(admin, tournamentId);
}

async function generateNextSwissRound(
  admin: SupabaseClient,
  tournamentId: string,
  roundNumber: number,
  allMatches: { id: string }[],
): Promise<void> {
  const { data: participants } = await admin
    .from('tournament_participants')
    .select('user_id, points, buchholz')
    .eq('tournament_id', tournamentId);
  if (!participants) return;

  const standings: SwissStanding[] = participants.map((p) => ({
    playerId: p.user_id, points: p.points ?? 0, buchholz: Number(p.buchholz ?? 0),
  }));

  // Build previous-pairings set from completed matches.
  const { data: played } = await admin
    .from('tournament_matches')
    .select('player1_id, player2_id')
    .eq('tournament_id', tournamentId);
  const previous = new Set<string>();
  for (const m of played ?? []) {
    if (m.player1_id && m.player2_id) previous.add(pairingKey(m.player1_id, m.player2_id));
  }

  const planned = generateSwissNextRound(roundNumber, standings, previous, allMatches.length + 1);
  await insertPlannedMatches(admin, tournamentId, planned);
  await autoStartReadyMatches(admin, tournamentId, roundNumber);
}

// Insert planned matches; resolve nextMatch linkage localId → uuid in a 2nd pass.
export async function insertPlannedMatches(
  admin: SupabaseClient,
  tournamentId: string,
  planned: PlannedMatch[],
): Promise<void> {
  const rows = planned.map((m) => ({
    tournament_id: tournamentId,
    round: m.round,
    match_number: m.matchNumber,
    bracket_side: m.bracketSide,
    player1_id: m.player1Id,
    player2_id: m.player2Id,
    player1_seed: m.player1Seed,
    player2_seed: m.player2Seed,
    status: m.isBye ? 'bye' : (m.player1Id && m.player2Id ? 'ready' : 'pending'),
  }));

  const { data: inserted } = await admin
    .from('tournament_matches')
    .insert(rows)
    .select('id, round, match_number, bracket_side');
  if (!inserted) return;

  // localId → uuid
  const idByLocal = new Map<string, string>();
  for (const r of inserted) {
    idByLocal.set(`${r.bracket_side}:${r.round}:${r.match_number}`, r.id);
  }

  // Resolve next_match linkage.
  for (const m of planned) {
    if (!m.nextMatchLocalId) continue;
    const selfId = idByLocal.get(m.localId);
    const nextId = idByLocal.get(m.nextMatchLocalId);
    if (selfId && nextId) {
      await admin.from('tournament_matches')
        .update({ next_match_id: nextId, next_match_slot: m.nextMatchSlot })
        .eq('id', selfId);
    }
  }

  // Auto-advance round-1 byes into their next match.
  for (const m of planned) {
    if (!m.isBye || !m.nextMatchLocalId || !m.player1Id) continue;
    const nextId = idByLocal.get(m.nextMatchLocalId);
    if (nextId && m.nextMatchSlot) await advanceInto(admin, nextId, m.nextMatchSlot, m.player1Id);
  }
}

// Start every 'ready' match in a round that has no room yet.
export async function autoStartReadyMatches(
  admin: SupabaseClient,
  tournamentId: string,
  round?: number,
): Promise<void> {
  let q = admin.from('tournament_matches')
    .select('id')
    .eq('tournament_id', tournamentId)
    .eq('status', 'ready')
    .is('room_id', null);
  if (round !== undefined) q = q.eq('round', round);
  const { data: ready } = await q;
  for (const m of ready ?? []) {
    await startTournamentMatch(admin, m.id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// completeTournament — final standings + prize payout with rake + Gem Cups.
// Idempotent via tournaments.status + tournament_payouts unique(place).
// ─────────────────────────────────────────────────────────────────────────────
export async function completeTournament(
  admin: SupabaseClient,
  tournamentId: string,
): Promise<void> {
  const { data: t } = await admin
    .from('tournaments')
    .select('id, status, prize_pool, rake_percent, settings')
    .eq('id', tournamentId)
    .single();
  if (!t || t.status === 'completed' || t.status === 'cancelled') return;

  // Standings: wins desc, points desc, losses asc, seed asc.
  const { data: participants } = await admin
    .from('tournament_participants')
    .select('user_id, wins, losses, draws, points, seed')
    .eq('tournament_id', tournamentId);
  const ranked = [...(participants ?? [])].sort((a, b) =>
    (b.wins ?? 0) - (a.wins ?? 0) ||
    (b.points ?? 0) - (a.points ?? 0) ||
    (a.losses ?? 0) - (b.losses ?? 0) ||
    (a.seed ?? 9999) - (b.seed ?? 9999));

  const finalStandings = ranked.map((p, i) => ({
    place: i + 1, user_id: p.user_id, wins: p.wins, losses: p.losses, points: p.points,
  }));
  const placeToUser = new Map<number, string>();
  finalStandings.forEach((s) => placeToUser.set(s.place, s.user_id));

  // Entry pool from the ledger (authoritative), minus rake.
  const { data: ledger } = await admin
    .from('tournament_entry_ledger')
    .select('coins_paid, gems_paid')
    .eq('tournament_id', tournamentId)
    .eq('refunded', false);
  const grossCoins = (ledger ?? []).reduce((s, r) => s + (r.coins_paid ?? 0), 0);
  const grossGems = (ledger ?? []).reduce((s, r) => s + (r.gems_paid ?? 0), 0);
  const rake = Number(t.rake_percent ?? 0) / 100;
  const netCoins = Math.floor(grossCoins * (1 - rake));
  const netGems = Math.floor(grossGems * (1 - rake));

  // Prize pool, clamped so payouts never exceed the net pool.
  const prizes = (t.prize_pool as { place: number; coins?: number; gems?: number }[]) ?? [];
  const demandCoins = prizes.reduce((s, p) => s + (p.coins ?? 0), 0);
  const demandGems = prizes.reduce((s, p) => s + (p.gems ?? 0), 0);
  const coinScale = demandCoins > netCoins && demandCoins > 0 ? netCoins / demandCoins : 1;
  const gemScale = demandGems > netGems && demandGems > 0 ? netGems / demandGems : 1;

  // Gem Cup: platform-seeded gem bonuses for top places (settings.gem_cup { "1":10,... }).
  const gemCup = (t.settings as { gem_cup?: Record<string, number> } | null)?.gem_cup ?? {};

  for (const prize of prizes) {
    const userId = placeToUser.get(prize.place);
    if (!userId) continue;
    const coins = Math.floor((prize.coins ?? 0) * coinScale);
    const gems = Math.floor((prize.gems ?? 0) * gemScale);
    const gemCupBonus = gemCup[String(prize.place)] ?? 0;

    // Per-place guard: insert-once; if it already exists, skip crediting.
    const { data: guard } = await admin
      .from('tournament_payouts')
      .upsert(
        { tournament_id: tournamentId, place: prize.place, user_id: userId, coins, gems, gem_cup_bonus: gemCupBonus },
        { onConflict: 'tournament_id,place', ignoreDuplicates: true },
      )
      .select('id');
    if (!guard || guard.length === 0) continue; // already paid

    if (coins > 0) await creditCurrency(admin, userId, 'coins', coins, 'tournament_prize', tournamentId);
    if (gems > 0) await creditCurrency(admin, userId, 'gems', gems, 'tournament_prize', tournamentId);
    if (gemCupBonus > 0) await creditCurrency(admin, userId, 'gems', gemCupBonus, 'tournament_prize', tournamentId);
  }

  const winnerId = placeToUser.get(1) ?? null;
  if (winnerId) {
    await admin.from('tournament_participants')
      .update({ status: 'winner' })
      .eq('tournament_id', tournamentId).eq('user_id', winnerId);
  }

  await admin.from('tournaments').update({
    status: 'completed',
    winner_id: winnerId,
    final_standings: finalStandings,
    end_time: new Date().toISOString(),
  }).eq('id', tournamentId);
}

// ─────────────────────────────────────────────────────────────────────────────
// refundAllEntries — used by cancellation + insufficient-participants abort.
// ─────────────────────────────────────────────────────────────────────────────
export async function refundAllEntries(
  admin: SupabaseClient,
  tournamentId: string,
): Promise<void> {
  const { data: ledger } = await admin
    .from('tournament_entry_ledger')
    .select('id, user_id, coins_paid, gems_paid, refunded')
    .eq('tournament_id', tournamentId)
    .eq('refunded', false);

  for (const row of ledger ?? []) {
    // Flip refunded first (guard) — only proceed if we won the update race.
    const { data: flipped } = await admin
      .from('tournament_entry_ledger')
      .update({ refunded: true })
      .eq('id', row.id)
      .eq('refunded', false)
      .select('id');
    if (!flipped || flipped.length === 0) continue;

    if (row.coins_paid > 0) await creditCurrency(admin, row.user_id, 'coins', row.coins_paid, 'tournament_refund', tournamentId);
    if (row.gems_paid > 0) await creditCurrency(admin, row.user_id, 'gems', row.gems_paid, 'tournament_refund', tournamentId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// forfeitTournamentMatch — opponent advances (used for disconnect/no-show).
// ─────────────────────────────────────────────────────────────────────────────
export async function forfeitTournamentMatch(
  admin: SupabaseClient,
  matchId: string,
  forfeitingUserId: string,
): Promise<void> {
  const { data: match } = await admin
    .from('tournament_matches')
    .select('*')
    .eq('id', matchId)
    .single();
  if (!match || match.status === 'completed') return;

  const winnerId = match.player1_id === forfeitingUserId ? match.player2_id : match.player1_id;
  if (!winnerId) return;

  await admin.from('tournament_matches').update({
    winner_id: winnerId,
    result_details: { forfeit: true, forfeited_by: forfeitingUserId },
    status: 'completed',
    completed_at: new Date().toISOString(),
  }).eq('id', matchId);

  const { data: t } = await admin.from('tournaments').select('format').eq('id', match.tournament_id).single();
  const isElim = t?.format === 'single_elimination' || t?.format === 'double_elimination';
  await bumpParticipant(admin, match.tournament_id, winnerId, { win: true, draw: false });
  await bumpParticipant(admin, match.tournament_id, forfeitingUserId, { win: false, draw: false, eliminate: isElim });

  if (match.next_match_id && match.next_match_slot) {
    await advanceInto(admin, match.next_match_id, match.next_match_slot, winnerId);
  }
  await checkTournamentProgress(admin, match.tournament_id, t?.format ?? '');
}
