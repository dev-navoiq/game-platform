import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { creditCurrency } from './currency.ts';
import { sendPush } from './push.ts';
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
    .select('id, name, status, format, min_participants, current_participants, team_size, allow_solo_pairing')
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

  // ── Build entrants: individuals, or teams keyed by captain ───────────────
  // The bracket operates on ENTRANT ids. For team tournaments the entrant is
  // the team, represented by its captain's user id (player1/2_id stay
  // captains, so seeds/swiss/forfeit paths are shape-uniform), with
  // team1/2_id carried alongside on matches.
  const { data: participants } = await admin
    .from('tournament_participants')
    .select('user_id, team_id, profiles!inner(level)')
    .eq('tournament_id', t.id);
  if (!participants || participants.length < 2) {
    return { status: 'error', code: 'NOT_ENOUGH_PARTICIPANTS', httpStatus: 409 };
  }
  const levelOf = (p: { profiles: unknown }) =>
    (p.profiles as { level: number }).level ?? 1;

  interface Entrant { captainId: string; teamId: string | null; members: string[]; level: number }
  let entrants: Entrant[];

  if (t.team_size === 2) {
    const { data: teamRows } = await admin
      .from('tournament_teams')
      .select('id, captain_id')
      .eq('tournament_id', t.id);
    const captainOf = new Map((teamRows ?? []).map((r) => [r.id as string, r.captain_id as string]));

    const byTeam = new Map<string, { user_id: string; level: number }[]>();
    let solos: { user_id: string; level: number }[] = [];
    for (const p of participants) {
      const entry = { user_id: p.user_id as string, level: levelOf(p) };
      if (p.team_id) {
        const list = byTeam.get(p.team_id as string) ?? [];
        list.push(entry);
        byTeam.set(p.team_id as string, list);
      } else {
        solos.push(entry);
      }
    }

    // Pair solos strongest-with-weakest → balanced scratch teams.
    if (t.allow_solo_pairing) {
      solos.sort((a, b) => b.level - a.level);
      while (solos.length >= 2) {
        const a = solos.shift()!;
        const b = solos.pop()!;
        const { data: team } = await admin
          .from('tournament_teams')
          .insert({ tournament_id: t.id, captain_id: a.user_id })
          .select('id')
          .single();
        if (!team) { solos.unshift(a); break; }
        await admin.from('tournament_participants')
          .update({ team_id: team.id })
          .eq('tournament_id', t.id)
          .in('user_id', [a.user_id, b.user_id]);
        byTeam.set(team.id as string, [a, b]);
        captainOf.set(team.id as string, a.user_id);
      }
    }

    // Drop + refund anyone without a complete team (leftover solos, 1-member teams).
    const dropped: string[] = solos.map((s) => s.user_id);
    for (const [teamId, members] of [...byTeam.entries()]) {
      if (members.length !== t.team_size) {
        dropped.push(...members.map((m) => m.user_id));
        byTeam.delete(teamId);
        await admin.from('tournament_teams').delete().eq('id', teamId);
      }
    }
    for (const uid of dropped) {
      await refundAndDropParticipant(admin, t.id, uid);
    }

    entrants = [...byTeam.entries()].map(([teamId, members]) => ({
      captainId: captainOf.get(teamId) ?? members[0].user_id,
      teamId,
      members: [
        captainOf.get(teamId) ?? members[0].user_id,
        ...members.map((m) => m.user_id).filter((id) => id !== (captainOf.get(teamId) ?? members[0].user_id)),
      ],
      level: members.reduce((s, m) => s + m.level, 0) / members.length,
    }));

    // Re-check viability after drops (min counts PLAYERS).
    if (entrants.length < 2 || entrants.length * t.team_size < t.min_participants) {
      await refundAllEntries(admin, t.id);
      await admin.from('tournaments').update({ status: 'cancelled' }).eq('id', t.id);
      return { status: 'cancelled', reason: 'insufficient_participants' };
    }
  } else {
    entrants = participants.map((p) => ({
      captainId: p.user_id as string,
      teamId: null,
      members: [p.user_id as string],
      level: levelOf(p),
    }));
  }

  // ── Seed entrants: by level desc, random tiebreak ────────────────────────
  const ranked = entrants
    .map((e) => ({ ...e, rand: crypto.getRandomValues(new Uint32Array(1))[0] }))
    .sort((a, b) => b.level - a.level || a.rand - b.rand);

  const ids = ranked.map((r) => r.captainId);
  const seeds = ranked.map((_, i) => i + 1);

  // Persist seed + activate (every member of an entrant shares the seed).
  for (let i = 0; i < ranked.length; i++) {
    await admin.from('tournament_participants')
      .update({ seed: i + 1, status: 'active' })
      .eq('tournament_id', t.id).in('user_id', ranked[i].members);
  }

  // ── Generate + insert bracket ────────────────────────────────────────────
  let planned: PlannedMatch[];
  if (t.format === 'single_elimination') planned = generateSingleElimination(ids, seeds);
  else if (t.format === 'round_robin') planned = generateRoundRobin(ids);
  else planned = generateSwissFirstRound(ids, seeds); // swiss

  const teamByCaptain = t.team_size === 2
    ? new Map(ranked.map((r) => [r.captainId, r.teamId as string]))
    : undefined;
  await insertPlannedMatches(admin, t.id, planned, teamByCaptain);

  // ── Go live + create rooms for round-1 ready matches ─────────────────────
  await admin.from('tournaments').update({ status: 'in_progress' }).eq('id', t.id);
  await autoStartReadyMatches(admin, t.id);

  // Lifecycle push (M0 backbone). Failures must never abort a started
  // tournament — the bracket is already live.
  try {
    await sendPush(admin, ranked.flatMap((r) => r.members), 'tournament_updates', {
      title: t.name ?? 'Tournament',
      body: 'The tournament has started — your first match is ready!',
      data: { route: `/tournament/${t.id}` },
    });
  } catch (e) {
    console.error('tournament start push failed:', e);
  }

  return { status: 'started', matches: planned.length, format: t.format };
}

// Refund (via ledger guard) + remove a participant who cannot play — used for
// unpaired solos / incomplete teams at start time.
async function refundAndDropParticipant(
  admin: SupabaseClient,
  tournamentId: string,
  userId: string,
): Promise<void> {
  const { data: row } = await admin
    .from('tournament_entry_ledger')
    .select('id, coins_paid, gems_paid, refunded')
    .eq('tournament_id', tournamentId)
    .eq('user_id', userId)
    .maybeSingle();
  if (row && !row.refunded) {
    const { data: flipped } = await admin
      .from('tournament_entry_ledger')
      .update({ refunded: true })
      .eq('id', row.id).eq('refunded', false)
      .select('id');
    if (flipped && flipped.length > 0) {
      if (row.coins_paid > 0) await creditCurrency(admin, userId, 'coins', row.coins_paid, 'tournament_refund', tournamentId);
      if (row.gems_paid > 0) await creditCurrency(admin, userId, 'gems', row.gems_paid, 'tournament_refund', tournamentId);
    }
  }
  await admin.from('tournament_participants')
    .delete().eq('tournament_id', tournamentId).eq('user_id', userId);
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
    .select('id, tournament_id, player1_id, player2_id, team1_id, team2_id, status, room_id')
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

  // ── Seat order ───────────────────────────────────────────────────────────
  // Team matches seat partners OPPOSITE (0/2 vs 1/3): the 29/bridge outcome
  // adapters team by seat parity (idx % 2), so [t1a, t2a, t1b, t2b] puts
  // team1 on parity 0 and team2 on parity 1. Captains (player1/2_id) sit
  // first within their team.
  let seatOrder: string[];
  if (match.team1_id && match.team2_id) {
    const { data: members } = await admin
      .from('tournament_participants')
      .select('user_id, team_id')
      .in('team_id', [match.team1_id, match.team2_id]);
    const side = (teamId: string, captain: string) => {
      const ids = (members ?? []).filter((m) => m.team_id === teamId).map((m) => m.user_id as string);
      return [captain, ...ids.filter((id) => id !== captain)];
    };
    const t1 = side(match.team1_id as string, match.player1_id as string);
    const t2 = side(match.team2_id as string, match.player2_id as string);
    if (t1.length !== 2 || t2.length !== 2) return null; // roster incomplete — repair tick will retry
    seatOrder = [t1[0], t2[0], t1[1], t2[1]];
  } else {
    seatOrder = [match.player1_id as string, match.player2_id as string];
  }
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
      max_players: seatOrder.length,
      current_players: seatOrder.length,
      is_private: true,
      config: { tournament_id: match.tournament_id, tournament_match_id: matchId },
    })
    .select('id, code')
    .single();
  if (roomErr || !newRoom) throw new Error(`tournament room create failed: ${roomErr?.message}`);

  // Seat everyone in order (partners land opposite for team matches).
  await admin.from('room_players').insert(
    seatOrder.map((uid, i) => ({
      room_id: newRoom.id, user_id: uid, seat_index: i, is_spectator: false,
    })),
  );

  // Build the authoritative initial state and create the game_states row.
  const dealerIndex = crypto.getRandomValues(new Uint8Array(1))[0] % seatOrder.length;
  const state = buildInitialState(tournament.game_type, seatOrder, dealerIndex, socialMode);
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
  for (const pid of seatOrder) {
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
  const sides = await matchSides(admin, match);
  // Any member's outcome represents the side — team adapters (29/bridge) give
  // every member of a partnership the same result.
  const o1 = outcomes.find((o) => sides.side1.includes(o.user_id));
  const o2 = outcomes.find((o) => sides.side2.includes(o.user_id));

  // Resolve winner (tiebreak draws by better seed = lower seed number).
  let side1Wins: boolean;
  let isDraw = false;
  if (o1 && o2 && o1.result === 'draw' && o2.result === 'draw') {
    isDraw = true;
    side1Wins = (match.player1_seed ?? 9999) <= (match.player2_seed ?? 9999);
  } else if (o1?.result === 'win') {
    side1Wins = true;
  } else if (o2?.result === 'win') {
    side1Wins = false;
  } else {
    side1Wins = (o1?.position ?? 99) <= (o2?.position ?? 99);
  }
  const winnerId = side1Wins ? sides.cap1 : sides.cap2;
  const winnerTeamId = side1Wins ? sides.team1 : sides.team2;
  const winnerSide = side1Wins ? sides.side1 : sides.side2;
  const loserSide = side1Wins ? sides.side2 : sides.side1;

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

  // Update participant standings (every member of each side).
  for (const uid of winnerSide) {
    await bumpParticipant(admin, match.tournament_id, uid, { win: true, draw: isDraw });
  }
  for (const uid of loserSide) {
    await bumpParticipant(admin, match.tournament_id, uid, { win: false, draw: isDraw, eliminate: isElim && !isDraw });
  }

  // Advance winner into the next match (elimination brackets).
  if (match.next_match_id && match.next_match_slot) {
    await advanceInto(admin, match.next_match_id, match.next_match_slot, winnerId, winnerTeamId);
  }

  // Progress / completion.
  await checkTournamentProgress(admin, match.tournament_id, format);
}

// Resolve a match's two sides: captains, full member lists, and team ids.
// Individual matches degrade to singleton sides.
async function matchSides(
  admin: SupabaseClient,
  match: Record<string, unknown>,
): Promise<{
  cap1: string; cap2: string;
  side1: string[]; side2: string[];
  team1: string | null; team2: string | null;
}> {
  const cap1 = match.player1_id as string;
  const cap2 = match.player2_id as string;
  const team1 = (match.team1_id as string | null) ?? null;
  const team2 = (match.team2_id as string | null) ?? null;
  if (!team1 || !team2) {
    return { cap1, cap2, side1: [cap1], side2: [cap2], team1, team2 };
  }
  const { data: members } = await admin
    .from('tournament_participants')
    .select('user_id, team_id')
    .in('team_id', [team1, team2]);
  const of = (teamId: string, captain: string) => {
    const ids = (members ?? []).filter((m) => m.team_id === teamId).map((m) => m.user_id as string);
    return ids.length ? ids : [captain];
  };
  return { cap1, cap2, side1: of(team1, cap1), side2: of(team2, cap2), team1, team2 };
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
  teamId: string | null = null,
): Promise<void> {
  const col = slot === 1 ? 'player1_id' : 'player2_id';
  const teamCol = slot === 1 ? 'team1_id' : 'team2_id';
  await admin.from('tournament_matches')
    .update({ [col]: playerId, ...(teamId ? { [teamCol]: teamId } : {}) })
    .eq('id', nextMatchId);

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

  // Team tournaments pair by CAPTAIN (one standing per team — members carry
  // identical stats, so captains represent their team without double-counting).
  const { data: teamRows } = await admin
    .from('tournament_teams')
    .select('id, captain_id')
    .eq('tournament_id', tournamentId);
  const teamByCaptain = (teamRows && teamRows.length > 0)
    ? new Map(teamRows.map((r) => [r.captain_id as string, r.id as string]))
    : undefined;
  const standing = teamByCaptain
    ? participants.filter((p) => teamByCaptain.has(p.user_id as string))
    : participants;

  const standings: SwissStanding[] = standing.map((p) => ({
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
  await insertPlannedMatches(admin, tournamentId, planned, teamByCaptain);
  await autoStartReadyMatches(admin, tournamentId, roundNumber);
}

// Insert planned matches; resolve nextMatch linkage localId → uuid in a 2nd pass.
// teamByCaptain (team tournaments): captain user id → team id, so match rows
// carry team1/2_id alongside the captain in player1/2_id.
export async function insertPlannedMatches(
  admin: SupabaseClient,
  tournamentId: string,
  planned: PlannedMatch[],
  teamByCaptain?: Map<string, string>,
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
    team1_id: m.player1Id ? teamByCaptain?.get(m.player1Id) ?? null : null,
    team2_id: m.player2Id ? teamByCaptain?.get(m.player2Id) ?? null : null,
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
    if (nextId && m.nextMatchSlot) {
      await advanceInto(admin, nextId, m.nextMatchSlot, m.player1Id, teamByCaptain?.get(m.player1Id) ?? null);
    }
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
    .select('id, status, prize_pool, rake_percent, settings, is_official, team_size')
    .eq('id', tournamentId)
    .single();
  if (!t || t.status === 'completed' || t.status === 'cancelled') return;

  // Standings: wins desc, points desc, losses asc, seed asc.
  // Team tournaments rank one ENTRY per team (captain represents; members
  // carry identical stats) and remember the members for prize splitting.
  const { data: participants } = await admin
    .from('tournament_participants')
    .select('user_id, team_id, wins, losses, draws, points, seed')
    .eq('tournament_id', tournamentId);
  const { data: teamRows } = await admin
    .from('tournament_teams')
    .select('id, captain_id')
    .eq('tournament_id', tournamentId);
  const captainOf = new Map((teamRows ?? []).map((r) => [r.id as string, r.captain_id as string]));

  const isTeams = t.team_size === 2 && captainOf.size > 0;
  const entries = isTeams
    ? (participants ?? []).filter((p) => p.team_id && captainOf.get(p.team_id as string) === p.user_id)
    : (participants ?? []);
  const membersOf = (p: { user_id: string; team_id: string | null }) =>
    p.team_id
      ? (participants ?? []).filter((m) => m.team_id === p.team_id).map((m) => m.user_id as string)
      : [p.user_id as string];

  const ranked = [...entries].sort((a, b) =>
    (b.wins ?? 0) - (a.wins ?? 0) ||
    (b.points ?? 0) - (a.points ?? 0) ||
    (a.losses ?? 0) - (b.losses ?? 0) ||
    (a.seed ?? 9999) - (b.seed ?? 9999));

  const finalStandings = ranked.map((p, i) => ({
    place: i + 1, user_id: p.user_id, wins: p.wins, losses: p.losses, points: p.points,
    ...(isTeams ? { team_id: p.team_id, members: membersOf(p) } : {}),
  }));
  const placeToUser = new Map<number, string>();
  const placeToMembers = new Map<number, string[]>();
  ranked.forEach((p, i) => {
    placeToUser.set(i + 1, p.user_id as string);
    placeToMembers.set(i + 1, membersOf(p));
  });

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

  // Gem Cup: platform-FUNDED gem bonuses for top places (settings.gem_cup { "1":10,... }).
  // These mint gems from nothing, so they are honored ONLY on official
  // (admin-created) tournaments — player-created tournaments cannot carry a
  // gem_cup (enforced in RLS) — and each bonus is capped as defense-in-depth
  // against a mis-seeded config. See SECURITY-AUDIT C3 / SECURITY-GUIDELINES E5.
  const MAX_GEM_CUP_PER_PLACE = 5000;
  const gemCup = t.is_official
    ? ((t.settings as { gem_cup?: Record<string, number> } | null)?.gem_cup ?? {})
    : {};

  for (const prize of prizes) {
    const userId = placeToUser.get(prize.place);
    const members = placeToMembers.get(prize.place) ?? (userId ? [userId] : []);
    if (!userId || members.length === 0) continue;
    const coins = Math.floor((prize.coins ?? 0) * coinScale);
    const gems = Math.floor((prize.gems ?? 0) * gemScale);
    const rawGemCup = Math.max(0, Math.floor(Number(gemCup[String(prize.place)] ?? 0)));
    const gemCupBonus = Math.min(rawGemCup, MAX_GEM_CUP_PER_PLACE);

    // Per-place guard: insert-once; if it already exists, skip crediting.
    // For team places the payout row records the captain + FULL amounts; the
    // credits below split equally between members (remainder → captain).
    const { data: guard } = await admin
      .from('tournament_payouts')
      .upsert(
        { tournament_id: tournamentId, place: prize.place, user_id: userId, coins, gems, gem_cup_bonus: gemCupBonus },
        { onConflict: 'tournament_id,place', ignoreDuplicates: true },
      )
      .select('id');
    if (!guard || guard.length === 0) continue; // already paid

    const n = members.length;
    const shareOf = (total: number, memberIdx: number) => {
      const base = Math.floor(total / n);
      // Captain (members[0]) takes the integer remainder.
      return memberIdx === 0 ? total - base * (n - 1) : base;
    };
    for (let i = 0; i < members.length; i++) {
      const uid = members[i];
      const c = shareOf(coins, i);
      const g = shareOf(gems, i) + shareOf(gemCupBonus, i);
      if (c > 0) await creditCurrency(admin, uid, 'coins', c, 'tournament_prize', tournamentId);
      if (g > 0) await creditCurrency(admin, uid, 'gems', g, 'tournament_prize', tournamentId);
    }
  }

  const winnerId = placeToUser.get(1) ?? null;
  const winnerMembers = placeToMembers.get(1) ?? (winnerId ? [winnerId] : []);
  if (winnerMembers.length > 0) {
    await admin.from('tournament_participants')
      .update({ status: 'winner' })
      .eq('tournament_id', tournamentId).in('user_id', winnerMembers);
  }

  await admin.from('tournaments').update({
    status: 'completed',
    winner_id: winnerId,
    final_standings: finalStandings,
    end_time: new Date().toISOString(),
  }).eq('id', tournamentId);

  // Lifecycle pushes: everyone gets standings; the winner gets their moment.
  try {
    const { data: allParts } = await admin
      .from('tournament_participants')
      .select('user_id')
      .eq('tournament_id', tournamentId);
    const participantIds = (allParts ?? [])
      .map((p: { user_id: string }) => p.user_id)
      .filter((id: string) => !winnerMembers.includes(id));
    if (winnerMembers.length > 0) {
      await sendPush(admin, winnerMembers, 'tournament_updates', {
        title: 'Champion! 🏆',
        body: 'You won the tournament — collect your prizes!',
        data: { route: `/tournament/${tournamentId}` },
      });
    }
    await sendPush(admin, participantIds, 'tournament_updates', {
      title: 'Tournament finished',
      body: 'See the final standings and payouts.',
      data: { route: `/tournament/${tournamentId}` },
    });
  } catch (e) {
    console.error('tournament complete push failed:', e);
  }
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

  // A forfeit by ANY member forfeits their whole side (a 29/bridge partnership
  // cannot play short-handed).
  const sides = await matchSides(admin, match);
  let side1Forfeits: boolean;
  if (sides.side1.includes(forfeitingUserId)) side1Forfeits = true;
  else if (sides.side2.includes(forfeitingUserId)) side1Forfeits = false;
  else return; // not a player in this match

  const winnerId = side1Forfeits ? sides.cap2 : sides.cap1;
  const winnerTeamId = side1Forfeits ? sides.team2 : sides.team1;
  const winnerSide = side1Forfeits ? sides.side2 : sides.side1;
  const loserSide = side1Forfeits ? sides.side1 : sides.side2;
  if (!winnerId) return;

  await admin.from('tournament_matches').update({
    winner_id: winnerId,
    result_details: { forfeit: true, forfeited_by: forfeitingUserId },
    status: 'completed',
    completed_at: new Date().toISOString(),
  }).eq('id', matchId);

  const { data: t } = await admin.from('tournaments').select('format').eq('id', match.tournament_id).single();
  const isElim = t?.format === 'single_elimination' || t?.format === 'double_elimination';
  for (const uid of winnerSide) {
    await bumpParticipant(admin, match.tournament_id, uid, { win: true, draw: false });
  }
  for (const uid of loserSide) {
    await bumpParticipant(admin, match.tournament_id, uid, { win: false, draw: false, eliminate: isElim });
  }

  if (match.next_match_id && match.next_match_slot) {
    await advanceInto(admin, match.next_match_id, match.next_match_slot, winnerId, winnerTeamId);
  }
  await checkTournamentProgress(admin, match.tournament_id, t?.format ?? '');
}
