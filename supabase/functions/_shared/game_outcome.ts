// Per-game end-state → normalized player outcomes.
//
// Game states differ in shape (team vs individual, scalar winner vs finish
// order), so each supported game type has a small adapter. Only the four game
// types with server-side rules are supported (twenty_nine, oh_hell, bridge,
// ludo); others return [] (no server-authoritative outcome yet).
//
// Returns one PlayerOutcome per player id found in the end state — INCLUDING
// bot ids. Callers filter to humans (room_players) before granting rewards or
// recording history.

export interface PlayerOutcome {
  user_id: string;
  result: 'win' | 'loss' | 'draw';
  position: number; // 1 = best
  points: number;   // that player's / team's session score
}

export function computeOutcomes(
  gameType: string,
  state: Record<string, unknown>,
): PlayerOutcome[] {
  switch (gameType) {
    case 'twenty_nine':
      return twentyNineOutcomes(state);
    case 'oh_hell':
      return ohHellOutcomes(state);
    case 'bridge':
      return bridgeOutcomes(state);
    case 'ludo':
      return ludoOutcomes(state);
    default:
      return [];
  }
}

// twenty_nine: 4 players in `playerOrder`, teams by seat parity (idx % 2),
// team game-points in `sessionScores` {0,1}. Winning team = higher sessionScore.
function twentyNineOutcomes(state: Record<string, unknown>): PlayerOutcome[] {
  const order = state.playerOrder as string[] | undefined;
  const scores = (state.sessionScores ?? {}) as Record<string, number>;
  if (!order?.length) return [];

  const s0 = Number(scores[0] ?? 0);
  const s1 = Number(scores[1] ?? 0);
  const draw = s0 === s1;
  const winningTeam = draw ? -1 : (s0 > s1 ? 0 : 1);

  return order.map((pid, idx) => {
    const team = idx % 2;
    const points = team === 0 ? s0 : s1;
    if (draw) return { user_id: pid, result: 'draw', position: 1, points };
    const win = team === winningTeam;
    return { user_id: pid, result: win ? 'win' : 'loss', position: win ? 1 : 2, points };
  });
}

// oh_hell: individual `scores` map; highest score wins (exact bid = 10 + bid).
function ohHellOutcomes(state: Record<string, unknown>): PlayerOutcome[] {
  const order = state.playerOrder as string[] | undefined;
  const scores = (state.scores ?? {}) as Record<string, number>;
  if (!order?.length) return [];
  return rankByScoreDesc(order.map((pid) => ({ pid, score: Number(scores[pid] ?? 0) })));
}

// bridge: 4 seats in `playerOrder` (N/E/S/W), partnership scores in `scores`
// {NS, EW}. Even seats = NS, odd seats = EW. Higher partnership score wins.
function bridgeOutcomes(state: Record<string, unknown>): PlayerOutcome[] {
  const order = state.playerOrder as string[] | undefined;
  const scores = (state.scores ?? {}) as Record<string, number>;
  if (!order?.length) return [];

  const ns = Number(scores.NS ?? 0);
  const ew = Number(scores.EW ?? 0);
  const draw = ns === ew;
  const winningTeam = draw ? '' : (ns > ew ? 'NS' : 'EW');

  return order.map((pid, idx) => {
    const team = idx % 2 === 0 ? 'NS' : 'EW';
    const points = team === 'NS' ? ns : ew;
    if (draw) return { user_id: pid, result: 'draw', position: 1, points };
    const win = team === winningTeam;
    return { user_id: pid, result: win ? 'win' : 'loss', position: win ? 1 : 2, points };
  });
}

// ludo: `finishedPlayers` is finish order (all players present at gameEnd);
// index 0 = winner. Placement points = N - finishIndex.
function ludoOutcomes(state: Record<string, unknown>): PlayerOutcome[] {
  const ids = state.playerIds as string[] | undefined;
  const finished = (state.finishedPlayers ?? []) as string[];
  if (!ids?.length) return [];

  const order = finished.length ? finished : ids;
  const n = ids.length;
  return order.map((pid, idx) => ({
    user_id: pid,
    result: idx === 0 ? 'win' : 'loss',
    position: idx + 1,
    points: n - idx,
  }));
}

// Shared: rank individual scores descending with dense positions; ties at the
// top are draws.
function rankByScoreDesc(
  entries: { pid: string; score: number }[],
): PlayerOutcome[] {
  const maxScore = Math.max(...entries.map((e) => e.score));
  const topCount = entries.filter((e) => e.score === maxScore).length;

  return entries.map(({ pid, score }) => {
    const strictlyAbove = entries.filter((e) => e.score > score).length;
    const position = strictlyAbove + 1;
    let result: PlayerOutcome['result'];
    if (score === maxScore) result = topCount > 1 ? 'draw' : 'win';
    else result = 'loss';
    return { user_id: pid, result, position, points: score };
  });
}
