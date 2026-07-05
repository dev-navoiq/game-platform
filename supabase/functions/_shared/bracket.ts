// Server-authoritative bracket generation. TypeScript port of the client
// bracket_generator.dart, with two fixes the client never had:
//   1. Match linkage uses a stable localId ("side:round:matchNumber") which the
//      caller resolves to real next_match_id UUIDs after inserting rows — the
//      client left next_match as a stringified match number that was never
//      resolved.
//   2. Byes are surfaced so the caller can auto-advance the lone player.
//
// Supported formats: single_elimination, round_robin, swiss (first round +
// standings-based next round). Double-elimination/multi-stage loser routing is
// intentionally NOT emitted here (the client never implemented it correctly);
// tournament-start rejects those formats until it's built + verified.

export interface PlannedMatch {
  round: number;
  matchNumber: number;
  bracketSide: string; // 'winners' | 'losers' | 'finals'
  player1Id: string | null;
  player2Id: string | null;
  player1Seed: number | null;
  player2Seed: number | null;
  isBye: boolean;
  localId: string;
  nextMatchLocalId: string | null;
  nextMatchSlot: number | null; // 1 = player1, 2 = player2
}

export interface SwissStanding {
  playerId: string;
  points: number;
  buchholz: number;
}

const localId = (side: string, round: number, matchNumber: number) =>
  `${side}:${round}:${matchNumber}`;

function newMatch(
  side: string,
  round: number,
  matchNumber: number,
  opts: Partial<PlannedMatch> = {},
): PlannedMatch {
  return {
    round,
    matchNumber,
    bracketSide: side,
    player1Id: opts.player1Id ?? null,
    player2Id: opts.player2Id ?? null,
    player1Seed: opts.player1Seed ?? null,
    player2Seed: opts.player2Seed ?? null,
    isBye: opts.isBye ?? false,
    localId: localId(side, round, matchNumber),
    nextMatchLocalId: null,
    nextMatchSlot: null,
  };
}

// ── Single Elimination ───────────────────────────────────────────────────────
export function generateSingleElimination(
  participantIds: string[],
  seeds?: number[],
): PlannedMatch[] {
  const n = participantIds.length;
  if (n < 2) throw new Error('Need at least 2 participants');

  const bracketSize = nextPowerOf2(n);
  const totalRounds = Math.ceil(Math.log2(bracketSize));
  const effectiveSeeds = seeds ?? participantIds.map((_, i) => i + 1);
  const seeded = seedParticipants(participantIds, effectiveSeeds, bracketSize);

  const matches: PlannedMatch[] = [];
  let matchNumber = 1;

  // Round 1
  for (let i = 0; i < bracketSize / 2; i++) {
    const p1 = seeded[i * 2];
    const p2 = seeded[i * 2 + 1];
    matches.push(newMatch('winners', 1, matchNumber++, {
      player1Id: p1?.id ?? null,
      player2Id: p2?.id ?? null,
      player1Seed: p1?.seed ?? null,
      player2Seed: p2?.seed ?? null,
      isBye: !p1 || !p2,
    }));
  }

  // Subsequent (empty) rounds
  let matchesInRound = bracketSize / 4;
  for (let round = 2; round <= totalRounds; round++) {
    for (let i = 0; i < matchesInRound; i++) {
      matches.push(newMatch('winners', round, matchNumber++));
    }
    matchesInRound = Math.max(1, Math.ceil(matchesInRound / 2));
  }

  linkBracketMatches(matches, 'winners');
  return matches;
}

// ── Round Robin ──────────────────────────────────────────────────────────────
export function generateRoundRobin(participantIds: string[]): PlannedMatch[] {
  const n = participantIds.length;
  if (n < 2) throw new Error('Need at least 2 participants');

  const participants: (string | null)[] = [...participantIds];
  if (n % 2 === 1) participants.push(null); // bye slot

  const rounds = participants.length - 1;
  const matchesPerRound = participants.length / 2;
  const matches: PlannedMatch[] = [];
  let matchNumber = 1;

  for (let round = 1; round <= rounds; round++) {
    for (let i = 0; i < matchesPerRound; i++) {
      const home = participants[i];
      const away = participants[participants.length - 1 - i];
      if (home !== null && away !== null) {
        matches.push(newMatch('winners', round, matchNumber++, {
          player1Id: home,
          player2Id: away,
        }));
      }
    }
    // Rotate, keeping the first fixed.
    const last = participants.pop()!;
    participants.splice(1, 0, last);
  }

  return matches;
}

// ── Swiss ────────────────────────────────────────────────────────────────────
export function generateSwissFirstRound(
  participantIds: string[],
  seeds?: number[],
): PlannedMatch[] {
  const n = participantIds.length;
  if (n < 2) throw new Error('Need at least 2 participants');

  const effectiveSeeds = seeds ?? participantIds.map((_, i) => i + 1);
  const indexed = participantIds.map((_, i) => i);
  indexed.sort((a, b) => effectiveSeeds[a] - effectiveSeeds[b]);

  const matches: PlannedMatch[] = [];
  let matchNumber = 1;
  const halfSize = Math.ceil(n / 2);

  for (let i = 0; i < halfSize; i++) {
    const opponentIndex = i + halfSize;
    if (opponentIndex >= n) {
      matches.push(newMatch('winners', 1, matchNumber++, {
        player1Id: participantIds[indexed[i]],
        player1Seed: effectiveSeeds[indexed[i]],
        isBye: true,
      }));
    } else {
      matches.push(newMatch('winners', 1, matchNumber++, {
        player1Id: participantIds[indexed[i]],
        player2Id: participantIds[indexed[opponentIndex]],
        player1Seed: effectiveSeeds[indexed[i]],
        player2Seed: effectiveSeeds[indexed[opponentIndex]],
      }));
    }
  }
  return matches;
}

export function generateSwissNextRound(
  roundNumber: number,
  standings: SwissStanding[],
  previousPairings: Set<string>,
  startingMatchNumber = 1,
): PlannedMatch[] {
  const sorted = [...standings].sort((a, b) => {
    const d = b.points - a.points;
    return d !== 0 ? d : b.buchholz - a.buchholz;
  });

  const matches: PlannedMatch[] = [];
  const paired = new Set<string>();
  let matchNumber = startingMatchNumber;

  for (let i = 0; i < sorted.length; i++) {
    if (paired.has(sorted[i].playerId)) continue;
    const player = sorted[i];
    let opponent: string | null = null;

    for (let j = i + 1; j < sorted.length; j++) {
      const cand = sorted[j];
      if (paired.has(cand.playerId)) continue;
      if (!previousPairings.has(pairingKey(player.playerId, cand.playerId))) {
        opponent = cand.playerId;
        paired.add(cand.playerId);
        break;
      }
    }
    paired.add(player.playerId);

    matches.push(newMatch('winners', roundNumber, matchNumber++, {
      player1Id: player.playerId,
      player2Id: opponent,
      isBye: opponent === null,
    }));
  }
  return matches;
}

export function recommendedSwissRounds(participants: number): number {
  return Math.ceil(Math.log2(participants));
}

export function pairingKey(a: string, b: string): string {
  return a < b ? `${a}:${b}` : `${b}:${a}`;
}

// ── Helpers ──────────────────────────────────────────────────────────────────
function nextPowerOf2(n: number): number {
  let power = 1;
  while (power < n) power *= 2;
  return power;
}

interface SeededPlayer { id: string; seed: number; }

function seedParticipants(
  participants: string[],
  seeds: number[],
  bracketSize: number,
): (SeededPlayer | null)[] {
  const seeded: (SeededPlayer | null)[] = new Array(bracketSize).fill(null);
  const order = getSeedOrder(bracketSize);
  for (let i = 0; i < participants.length; i++) {
    seeded[order[i]] = { id: participants[i], seed: seeds[i] };
  }
  return seeded;
}

// Standard bracket seeding order (1 vs 16, 8 vs 9, ...).
function getSeedOrder(size: number): number[] {
  if (size === 2) return [0, 1];
  const half = size / 2;
  const top = getSeedOrder(half);
  const bottom = top.map((i) => size - 1 - i);
  const result: number[] = [];
  for (let i = 0; i < half; i++) {
    result.push(top[i]);
    result.push(bottom[i]);
  }
  return result;
}

// Link each match to the next round's match by localId + slot.
function linkBracketMatches(matches: PlannedMatch[], side: string): void {
  const sideMatches = matches.filter((m) => m.bracketSide === side);
  const byRound = new Map<number, PlannedMatch[]>();
  for (const m of sideMatches) {
    if (!byRound.has(m.round)) byRound.set(m.round, []);
    byRound.get(m.round)!.push(m);
  }
  const rounds = [...byRound.keys()].sort((a, b) => a - b);
  for (let i = 0; i < rounds.length - 1; i++) {
    const current = byRound.get(rounds[i])!;
    const next = byRound.get(rounds[i + 1])!;
    for (let j = 0; j < current.length; j++) {
      const nextIdx = Math.floor(j / 2);
      if (nextIdx < next.length) {
        current[j].nextMatchLocalId = next[nextIdx].localId;
        current[j].nextMatchSlot = (j % 2) + 1;
      }
    }
  }
}
