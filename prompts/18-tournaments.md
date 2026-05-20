# 17 - Tournaments

> Implement tournament system with brackets, leaderboards, prizes, and scheduling.

## Task

Build a comprehensive tournament system with:
- Multiple tournament formats (Single Elimination, Double Elimination, Round Robin, Swiss)
- Scheduled and instant tournaments
- Brackets and matchmaking
- Prize pools (coins, gems, exclusive skins)
- Tournament chat and notifications
- Leaderboards and rankings

---

## Tournament Formats

| Format | Description | Best For |
|--------|-------------|----------|
| **Single Elimination** | Lose once, you're out | Quick tournaments, 8-64 players |
| **Double Elimination** | Lose twice to be eliminated | More forgiving, 8-32 players |
| **Round Robin** | Everyone plays everyone | Small groups, 4-8 players |
| **Swiss** | Paired by similar records | Large groups, fair matching |
| **Multi-Stage** | Group stage → Knockout | Large tournaments, 16-64 players |

---

## Database Schema

```sql
-- Tournament types
CREATE TYPE tournament_format AS ENUM (
  'single_elimination',
  'double_elimination',
  'round_robin',
  'swiss',
  'multi_stage'
);

CREATE TYPE tournament_status AS ENUM (
  'draft',           -- Being created
  'registration',    -- Open for registration
  'starting',        -- Registration closed, about to start
  'in_progress',     -- Tournament running
  'completed',       -- Finished
  'cancelled'        -- Cancelled
);

CREATE TYPE bracket_side AS ENUM ('winners', 'losers', 'finals');

-- Tournaments table
CREATE TABLE tournaments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Basic info
  name TEXT NOT NULL,
  description TEXT,
  game_type game_type NOT NULL,
  format tournament_format NOT NULL,

  -- Organizer
  organizer_id UUID REFERENCES profiles(id),
  is_official BOOLEAN DEFAULT FALSE,

  -- Timing
  registration_start TIMESTAMPTZ,
  registration_end TIMESTAMPTZ,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,

  -- Capacity
  min_participants INT NOT NULL DEFAULT 4,
  max_participants INT NOT NULL DEFAULT 32,
  current_participants INT DEFAULT 0,

  -- Entry
  entry_fee_coins INT DEFAULT 0,
  entry_fee_gems INT DEFAULT 0,
  is_free BOOLEAN GENERATED ALWAYS AS (entry_fee_coins = 0 AND entry_fee_gems = 0) STORED,

  -- Prizes
  prize_pool JSONB DEFAULT '[]',
  -- Example: [{"place": 1, "coins": 1000, "gems": 100, "skin_id": "champion_card"}]

  -- Settings
  settings JSONB DEFAULT '{}',
  -- game_settings, time_control, rounds (for swiss), etc.

  -- Status
  status tournament_status DEFAULT 'draft',
  winner_id UUID REFERENCES profiles(id),
  final_standings JSONB,

  -- Subscription requirement
  min_subscription_tier subscription_tier DEFAULT 'free',

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tournament participants
CREATE TABLE tournament_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Status
  status TEXT DEFAULT 'registered', -- 'registered', 'checked_in', 'active', 'eliminated', 'winner'
  seed INT, -- Seeding position (1 = top seed)
  current_round INT DEFAULT 0,

  -- Stats
  wins INT DEFAULT 0,
  losses INT DEFAULT 0,
  draws INT DEFAULT 0,
  points INT DEFAULT 0, -- For swiss/round robin
  game_wins INT DEFAULT 0, -- Tiebreaker
  buchholz DECIMAL(10,2) DEFAULT 0, -- Swiss tiebreaker

  -- Timestamps
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  checked_in_at TIMESTAMPTZ,
  eliminated_at TIMESTAMPTZ,

  UNIQUE(tournament_id, user_id)
);

-- Tournament brackets/matches
CREATE TABLE tournament_matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,

  -- Match position in bracket
  round INT NOT NULL,
  match_number INT NOT NULL,
  bracket_side bracket_side DEFAULT 'winners',

  -- Participants
  player1_id UUID REFERENCES profiles(id),
  player2_id UUID REFERENCES profiles(id),
  player1_seed INT,
  player2_seed INT,

  -- Result
  winner_id UUID REFERENCES profiles(id),
  player1_score INT,
  player2_score INT,
  result_details JSONB,

  -- Game room (if active)
  room_id UUID REFERENCES game_rooms(id),

  -- Status
  status TEXT DEFAULT 'pending', -- 'pending', 'ready', 'in_progress', 'completed', 'bye'

  -- Scheduling
  scheduled_time TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,

  -- Next match (for bracket progression)
  next_match_id UUID REFERENCES tournament_matches(id),
  next_match_slot INT, -- 1 = player1, 2 = player2

  -- For double elim
  loser_next_match_id UUID REFERENCES tournament_matches(id),

  UNIQUE(tournament_id, round, match_number, bracket_side)
);

-- Tournament chat
CREATE TABLE tournament_chat (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id),
  content TEXT NOT NULL,
  is_announcement BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_game ON tournaments(game_type);
CREATE INDEX idx_tournaments_start ON tournaments(start_time);
CREATE INDEX idx_tournament_participants ON tournament_participants(tournament_id);
CREATE INDEX idx_tournament_matches ON tournament_matches(tournament_id, round);

-- RLS
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_chat ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Tournaments are publicly visible" ON tournaments
  FOR SELECT USING (status != 'draft' OR organizer_id = auth.uid());

CREATE POLICY "Participants visible to all" ON tournament_participants
  FOR SELECT USING (TRUE);

CREATE POLICY "Users can register themselves" ON tournament_participants
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Matches visible to all" ON tournament_matches
  FOR SELECT USING (TRUE);

CREATE POLICY "Chat visible to participants" ON tournament_chat
  FOR SELECT USING (
    tournament_id IN (
      SELECT tournament_id FROM tournament_participants WHERE user_id = auth.uid()
    )
  );
```

---

## Tournament Service

```dart
// lib/features/tournaments/data/tournament_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

enum TournamentFormat {
  singleElimination,
  doubleElimination,
  roundRobin,
  swiss,
  multiStage,
}

enum TournamentStatus {
  draft,
  registration,
  starting,
  inProgress,
  completed,
  cancelled,
}

class Tournament {
  final String id;
  final String name;
  final String? description;
  final String gameType;
  final TournamentFormat format;
  final String? organizerId;
  final bool isOfficial;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime startTime;
  final DateTime? endTime;
  final int minParticipants;
  final int maxParticipants;
  final int currentParticipants;
  final int entryFeeCoins;
  final int entryFeeGems;
  final List<TournamentPrize> prizes;
  final TournamentStatus status;
  final String? winnerId;
  final Map<String, dynamic> settings;

  Tournament({
    required this.id,
    required this.name,
    this.description,
    required this.gameType,
    required this.format,
    this.organizerId,
    this.isOfficial = false,
    this.registrationStart,
    this.registrationEnd,
    required this.startTime,
    this.endTime,
    required this.minParticipants,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.entryFeeCoins = 0,
    this.entryFeeGems = 0,
    this.prizes = const [],
    this.status = TournamentStatus.draft,
    this.winnerId,
    this.settings = const {},
  });

  bool get isFree => entryFeeCoins == 0 && entryFeeGems == 0;
  bool get isFull => currentParticipants >= maxParticipants;
  bool get isRegistrationOpen =>
      status == TournamentStatus.registration &&
      !isFull &&
      (registrationEnd == null || DateTime.now().isBefore(registrationEnd!));

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      gameType: json['game_type'],
      format: TournamentFormat.values.byName(
        (json['format'] as String).replaceAll('_', ''),
      ),
      organizerId: json['organizer_id'],
      isOfficial: json['is_official'] ?? false,
      registrationStart: json['registration_start'] != null
          ? DateTime.parse(json['registration_start'])
          : null,
      registrationEnd: json['registration_end'] != null
          ? DateTime.parse(json['registration_end'])
          : null,
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      minParticipants: json['min_participants'],
      maxParticipants: json['max_participants'],
      currentParticipants: json['current_participants'] ?? 0,
      entryFeeCoins: json['entry_fee_coins'] ?? 0,
      entryFeeGems: json['entry_fee_gems'] ?? 0,
      prizes: (json['prize_pool'] as List?)
              ?.map((p) => TournamentPrize.fromJson(p))
              .toList() ??
          [],
      status: TournamentStatus.values.byName(json['status']),
      winnerId: json['winner_id'],
      settings: json['settings'] ?? {},
    );
  }
}

class TournamentPrize {
  final int place;
  final int coins;
  final int gems;
  final String? skinId;
  final String? title;

  TournamentPrize({
    required this.place,
    this.coins = 0,
    this.gems = 0,
    this.skinId,
    this.title,
  });

  factory TournamentPrize.fromJson(Map<String, dynamic> json) {
    return TournamentPrize(
      place: json['place'],
      coins: json['coins'] ?? 0,
      gems: json['gems'] ?? 0,
      skinId: json['skin_id'],
      title: json['title'],
    );
  }

  String get placeLabel {
    switch (place) {
      case 1:
        return '1st Place';
      case 2:
        return '2nd Place';
      case 3:
        return '3rd Place';
      default:
        return '${place}th Place';
    }
  }
}

class TournamentMatch {
  final String id;
  final String tournamentId;
  final int round;
  final int matchNumber;
  final String bracketSide;
  final String? player1Id;
  final String? player2Id;
  final String? player1Name;
  final String? player2Name;
  final int? player1Seed;
  final int? player2Seed;
  final String? winnerId;
  final int? player1Score;
  final int? player2Score;
  final String status;
  final DateTime? scheduledTime;
  final String? roomId;

  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchNumber,
    required this.bracketSide,
    this.player1Id,
    this.player2Id,
    this.player1Name,
    this.player2Name,
    this.player1Seed,
    this.player2Seed,
    this.winnerId,
    this.player1Score,
    this.player2Score,
    required this.status,
    this.scheduledTime,
    this.roomId,
  });

  bool get isBye => player1Id == null || player2Id == null;
  bool get isCompleted => status == 'completed';
  bool get isReady => status == 'ready' && player1Id != null && player2Id != null;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'],
      tournamentId: json['tournament_id'],
      round: json['round'],
      matchNumber: json['match_number'],
      bracketSide: json['bracket_side'],
      player1Id: json['player1_id'],
      player2Id: json['player2_id'],
      player1Name: json['player1']?['username'],
      player2Name: json['player2']?['username'],
      player1Seed: json['player1_seed'],
      player2Seed: json['player2_seed'],
      winnerId: json['winner_id'],
      player1Score: json['player1_score'],
      player2Score: json['player2_score'],
      status: json['status'],
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time'])
          : null,
      roomId: json['room_id'],
    );
  }
}

class TournamentRepository {
  final SupabaseClient _supabase;

  TournamentRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  Future<List<Tournament>> getUpcomingTournaments({
    String? gameType,
    int limit = 20,
  }) async {
    var query = _supabase
        .from('tournaments')
        .select()
        .in_('status', ['registration', 'starting'])
        .order('start_time', ascending: true)
        .limit(limit);

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query;
    return response.map((r) => Tournament.fromJson(r)).toList();
  }

  Future<List<Tournament>> getLiveTournaments({String? gameType}) async {
    var query = _supabase
        .from('tournaments')
        .select()
        .eq('status', 'in_progress')
        .order('start_time', ascending: true);

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query;
    return response.map((r) => Tournament.fromJson(r)).toList();
  }

  Future<List<Tournament>> getMyTournaments(String userId) async {
    final response = await _supabase
        .from('tournament_participants')
        .select('tournament:tournaments(*)')
        .eq('user_id', userId)
        .order('registered_at', ascending: false);

    return response
        .map((r) => Tournament.fromJson(r['tournament']))
        .toList();
  }

  Future<Tournament?> getTournament(String id) async {
    final response = await _supabase
        .from('tournaments')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? Tournament.fromJson(response) : null;
  }

  Future<List<TournamentMatch>> getBracket(String tournamentId) async {
    final response = await _supabase
        .from('tournament_matches')
        .select('''
          *,
          player1:profiles!player1_id(username, avatar_url),
          player2:profiles!player2_id(username, avatar_url)
        ''')
        .eq('tournament_id', tournamentId)
        .order('round', ascending: true)
        .order('match_number', ascending: true);

    return response.map((r) => TournamentMatch.fromJson(r)).toList();
  }

  Future<TournamentRegistrationResult> register(
    String tournamentId,
    String userId,
  ) async {
    try {
      // Check tournament status
      final tournament = await getTournament(tournamentId);
      if (tournament == null) {
        return TournamentRegistrationResult.tournamentNotFound;
      }

      if (!tournament.isRegistrationOpen) {
        return TournamentRegistrationResult.registrationClosed;
      }

      // Check entry fee
      if (!tournament.isFree) {
        final canAfford = await _checkBalance(
          userId,
          tournament.entryFeeCoins,
          tournament.entryFeeGems,
        );
        if (!canAfford) {
          return TournamentRegistrationResult.insufficientFunds;
        }

        // Deduct entry fee
        await _deductEntryFee(
          userId,
          tournamentId,
          tournament.entryFeeCoins,
          tournament.entryFeeGems,
        );
      }

      // Register
      await _supabase.from('tournament_participants').insert({
        'tournament_id': tournamentId,
        'user_id': userId,
      });

      return TournamentRegistrationResult.success;
    } catch (e) {
      if (e.toString().contains('duplicate')) {
        return TournamentRegistrationResult.alreadyRegistered;
      }
      return TournamentRegistrationResult.error;
    }
  }

  Future<bool> unregister(String tournamentId, String userId) async {
    try {
      // Check if can unregister (before tournament starts)
      final tournament = await getTournament(tournamentId);
      if (tournament == null ||
          tournament.status != TournamentStatus.registration) {
        return false;
      }

      // Refund entry fee if paid
      if (!tournament.isFree) {
        await _refundEntryFee(
          userId,
          tournamentId,
          tournament.entryFeeCoins,
          tournament.entryFeeGems,
        );
      }

      await _supabase
          .from('tournament_participants')
          .delete()
          .eq('tournament_id', tournamentId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkBalance(String userId, int coins, int gems) async {
    final response = await _supabase
        .from('profiles')
        .select('coins, gems')
        .eq('id', userId)
        .single();

    return (response['coins'] as int) >= coins &&
        (response['gems'] as int) >= gems;
  }

  Future<void> _deductEntryFee(
    String userId,
    String tournamentId,
    int coins,
    int gems,
  ) async {
    await _supabase.rpc('spend_currency', params: {
      'user_id': userId,
      'coin_amount': coins,
      'gem_amount': gems,
      'transaction_type': 'spend',
      'description': 'Tournament entry fee',
      'reference_id': tournamentId,
    });
  }

  Future<void> _refundEntryFee(
    String userId,
    String tournamentId,
    int coins,
    int gems,
  ) async {
    await _supabase.rpc('earn_currency', params: {
      'user_id': userId,
      'coin_amount': coins,
      'gem_amount': gems,
      'transaction_type': 'refund',
      'description': 'Tournament entry fee refund',
      'reference_id': tournamentId,
    });
  }

  Stream<List<TournamentMatch>> watchBracket(String tournamentId) {
    return _supabase
        .from('tournament_matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .map((data) => data.map((r) => TournamentMatch.fromJson(r)).toList());
  }
}

enum TournamentRegistrationResult {
  success,
  tournamentNotFound,
  registrationClosed,
  alreadyRegistered,
  insufficientFunds,
  error,
}
```

---

## Bracket Generator

```dart
// lib/features/tournaments/domain/bracket_generator.dart

import 'dart:math';

class BracketGenerator {
  /// Generate single elimination bracket
  static List<BracketMatch> generateSingleElimination({
    required List<String> participantIds,
    required List<int> seeds,
  }) {
    final matches = <BracketMatch>[];
    final n = participantIds.length;

    // Pad to power of 2
    final bracketSize = _nextPowerOf2(n);
    final rounds = (log(bracketSize) / log(2)).ceil();
    final byes = bracketSize - n;

    // Seed participants
    final seededParticipants = _seedParticipants(participantIds, seeds, bracketSize);

    // Generate first round matches
    var matchNumber = 1;
    for (var i = 0; i < bracketSize ~/ 2; i++) {
      final p1Index = i * 2;
      final p2Index = i * 2 + 1;

      matches.add(BracketMatch(
        round: 1,
        matchNumber: matchNumber++,
        bracketSide: 'winners',
        player1Id: seededParticipants[p1Index],
        player2Id: seededParticipants[p2Index],
        player1Seed: p1Index < n ? seeds[p1Index] : null,
        player2Seed: p2Index < n ? seeds[p2Index] : null,
        isBye: seededParticipants[p1Index] == null ||
            seededParticipants[p2Index] == null,
      ));
    }

    // Generate subsequent rounds
    var matchesInRound = bracketSize ~/ 4;
    for (var round = 2; round <= rounds; round++) {
      for (var i = 0; i < matchesInRound; i++) {
        matches.add(BracketMatch(
          round: round,
          matchNumber: matchNumber++,
          bracketSide: 'winners',
        ));
      }
      matchesInRound ~/= 2;
    }

    // Link matches
    _linkMatches(matches);

    return matches;
  }

  /// Generate double elimination bracket
  static List<BracketMatch> generateDoubleElimination({
    required List<String> participantIds,
    required List<int> seeds,
  }) {
    final matches = <BracketMatch>[];

    // Winners bracket (same as single elimination)
    final winnersMatches = generateSingleElimination(
      participantIds: participantIds,
      seeds: seeds,
    );

    for (final match in winnersMatches) {
      matches.add(match);
    }

    // Losers bracket
    final n = participantIds.length;
    final bracketSize = _nextPowerOf2(n);
    final winnersRounds = (log(bracketSize) / log(2)).ceil();
    final losersRounds = (winnersRounds - 1) * 2;

    var matchNumber = winnersMatches.length + 1;
    var matchesInRound = bracketSize ~/ 4;

    for (var round = 1; round <= losersRounds; round++) {
      final actualMatches = round.isOdd ? matchesInRound : matchesInRound;

      for (var i = 0; i < actualMatches; i++) {
        matches.add(BracketMatch(
          round: round,
          matchNumber: matchNumber++,
          bracketSide: 'losers',
        ));
      }

      if (round.isEven) {
        matchesInRound ~/= 2;
      }
    }

    // Grand finals
    matches.add(BracketMatch(
      round: 1,
      matchNumber: matchNumber++,
      bracketSide: 'finals',
    ));

    // Grand finals reset (if needed)
    matches.add(BracketMatch(
      round: 2,
      matchNumber: matchNumber++,
      bracketSide: 'finals',
    ));

    return matches;
  }

  /// Generate round robin schedule
  static List<BracketMatch> generateRoundRobin({
    required List<String> participantIds,
  }) {
    final matches = <BracketMatch>[];
    final n = participantIds.length;

    // Use circle method for scheduling
    final participants = List<String?>.from(participantIds);
    if (n.isOdd) {
      participants.add(null); // BYE
    }

    final rounds = participants.length - 1;
    final matchesPerRound = participants.length ~/ 2;
    var matchNumber = 1;

    for (var round = 1; round <= rounds; round++) {
      for (var i = 0; i < matchesPerRound; i++) {
        final home = participants[i];
        final away = participants[participants.length - 1 - i];

        if (home != null && away != null) {
          matches.add(BracketMatch(
            round: round,
            matchNumber: matchNumber++,
            bracketSide: 'winners',
            player1Id: home,
            player2Id: away,
          ));
        }
      }

      // Rotate participants (keep first fixed)
      final last = participants.removeLast();
      participants.insert(1, last);
    }

    return matches;
  }

  static int _nextPowerOf2(int n) {
    var power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  static List<String?> _seedParticipants(
    List<String> participants,
    List<int> seeds,
    int bracketSize,
  ) {
    // Standard seeding pattern for brackets
    // 1 vs 16, 8 vs 9, 4 vs 13, etc.
    final seeded = List<String?>.filled(bracketSize, null);
    final seedOrder = _getSeedOrder(bracketSize);

    for (var i = 0; i < participants.length; i++) {
      seeded[seedOrder[i]] = participants[i];
    }

    return seeded;
  }

  static List<int> _getSeedOrder(int size) {
    if (size == 2) return [0, 1];

    final halfSize = size ~/ 2;
    final topHalf = _getSeedOrder(halfSize);
    final bottomHalf = topHalf.map((i) => size - 1 - i).toList();

    final result = <int>[];
    for (var i = 0; i < halfSize; i++) {
      result.add(topHalf[i]);
      result.add(bottomHalf[i]);
    }

    return result;
  }

  static void _linkMatches(List<BracketMatch> matches) {
    // Link first round to second round, etc.
    final byRound = <int, List<BracketMatch>>{};
    for (final match in matches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }

    final rounds = byRound.keys.toList()..sort();

    for (var i = 0; i < rounds.length - 1; i++) {
      final currentRound = byRound[rounds[i]]!;
      final nextRound = byRound[rounds[i + 1]]!;

      for (var j = 0; j < currentRound.length; j++) {
        final nextMatchIndex = j ~/ 2;
        if (nextMatchIndex < nextRound.length) {
          currentRound[j].nextMatchId = nextRound[nextMatchIndex].matchNumber.toString();
          currentRound[j].nextMatchSlot = (j % 2) + 1;
        }
      }
    }
  }
}

class BracketMatch {
  final int round;
  final int matchNumber;
  final String bracketSide;
  String? player1Id;
  String? player2Id;
  int? player1Seed;
  int? player2Seed;
  bool isBye;
  String? nextMatchId;
  int? nextMatchSlot;

  BracketMatch({
    required this.round,
    required this.matchNumber,
    required this.bracketSide,
    this.player1Id,
    this.player2Id,
    this.player1Seed,
    this.player2Seed,
    this.isBye = false,
    this.nextMatchId,
    this.nextMatchSlot,
  });
}
```

---

## Tournament Bracket UI

```dart
// lib/features/tournaments/presentation/widgets/bracket_view.dart

import 'package:flutter/material.dart';

class BracketView extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String? currentUserId;
  final Function(TournamentMatch)? onMatchTap;

  const BracketView({
    super.key,
    required this.matches,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    // Group matches by round
    final roundsMap = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      roundsMap.putIfAbsent(match.round, () => []).add(match);
    }

    final rounds = roundsMap.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rounds.map((round) {
          return _BracketRound(
            roundNumber: round,
            totalRounds: rounds.length,
            matches: roundsMap[round]!,
            currentUserId: currentUserId,
            onMatchTap: onMatchTap,
          );
        }).toList(),
      ),
    );
  }
}

class _BracketRound extends StatelessWidget {
  final int roundNumber;
  final int totalRounds;
  final List<TournamentMatch> matches;
  final String? currentUserId;
  final Function(TournamentMatch)? onMatchTap;

  const _BracketRound({
    required this.roundNumber,
    required this.totalRounds,
    required this.matches,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final roundName = _getRoundName();

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 24),
      child: Column(
        children: [
          // Round header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              roundName,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Matches
          ...matches.asMap().entries.map((entry) {
            final index = entry.key;
            final match = entry.value;

            // Calculate vertical spacing for bracket alignment
            final spacing = _calculateSpacing(index);

            return Padding(
              padding: EdgeInsets.only(top: spacing),
              child: _MatchCard(
                match: match,
                isCurrentUser: match.player1Id == currentUserId ||
                    match.player2Id == currentUserId,
                onTap: onMatchTap != null ? () => onMatchTap!(match) : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getRoundName() {
    final roundsFromEnd = totalRounds - roundNumber + 1;
    switch (roundsFromEnd) {
      case 1:
        return 'Finals';
      case 2:
        return 'Semi-Finals';
      case 3:
        return 'Quarter-Finals';
      default:
        return 'Round $roundNumber';
    }
  }

  double _calculateSpacing(int matchIndex) {
    // First match has no top spacing
    if (matchIndex == 0) return 0;

    // Spacing increases for later rounds
    final baseSpacing = 20.0;
    final multiplier = pow(2, roundNumber - 1).toDouble();
    return baseSpacing * multiplier;
  }
}

class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const _MatchCard({
    required this.match,
    required this.isCurrentUser,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Colors.amber.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: match.isCompleted
                ? Colors.green.withOpacity(0.5)
                : isCurrentUser
                    ? Colors.amber.withOpacity(0.5)
                    : Colors.white24,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player 1
            _PlayerRow(
              name: match.player1Name ?? 'TBD',
              seed: match.player1Seed,
              score: match.player1Score,
              isWinner: match.winnerId == match.player1Id,
              isCurrentUser: match.player1Id == null
                  ? false
                  : match.player1Id == 'currentUserId', // Pass actual check
            ),

            const Divider(height: 8, color: Colors.white24),

            // Player 2
            _PlayerRow(
              name: match.player2Name ?? 'TBD',
              seed: match.player2Seed,
              score: match.player2Score,
              isWinner: match.winnerId == match.player2Id,
              isCurrentUser: match.player2Id == null
                  ? false
                  : match.player2Id == 'currentUserId',
            ),

            // Match status
            if (match.status == 'in_progress') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final int? seed;
  final int? score;
  final bool isWinner;
  final bool isCurrentUser;

  const _PlayerRow({
    required this.name,
    this.seed,
    this.score,
    required this.isWinner,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Seed
        if (seed != null)
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Text(
              '$seed',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),

        const SizedBox(width: 8),

        // Name
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isWinner ? Colors.green : Colors.white,
              fontWeight: isWinner || isCurrentUser
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Score
        if (score != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner
                  ? Colors.green.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                color: isWinner ? Colors.green : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Winner indicator
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.emoji_events, color: Colors.amber, size: 16),
          ),
      ],
    );
  }
}
```

---

## Tournament List Screen

```dart
// lib/features/tournaments/presentation/screens/tournaments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TournamentsScreen extends ConsumerStatefulWidget {
  const TournamentsScreen({super.key});

  @override
  ConsumerState<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends ConsumerState<TournamentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Live'),
            Tab(text: 'My Tournaments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UpcomingTab(),
          _LiveTab(),
          _MyTournamentsTab(),
        ],
      ),
    );
  }
}

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(upcomingTournamentsProvider);

    return tournaments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('No upcoming tournaments'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _TournamentCard(
              tournament: list[index],
              onTap: () => context.push('/tournament/${list[index].id}'),
            );
          },
        );
      },
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onTap;

  const _TournamentCard({
    required this.tournament,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (tournament.isOfficial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OFFICIAL',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    tournament.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Game type and format
            Row(
              children: [
                _Chip(
                  icon: Icons.games,
                  label: GameRegistry.getFactory(tournament.gameType)
                          ?.config
                          .displayName ??
                      tournament.gameType,
                ),
                const SizedBox(width: 8),
                _Chip(
                  icon: Icons.account_tree,
                  label: tournament.format.name,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Participants and time
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${tournament.currentParticipants}/${tournament.maxParticipants}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  _formatStartTime(tournament.startTime),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Entry fee and prizes
            Row(
              children: [
                if (tournament.isFree)
                  const _Chip(
                    icon: Icons.check_circle,
                    label: 'FREE',
                    color: Colors.green,
                  )
                else
                  _Chip(
                    icon: Icons.toll,
                    label: '${tournament.entryFeeCoins} coins',
                    color: Colors.amber,
                  ),
                const Spacer(),
                if (tournament.prizes.isNotEmpty) ...[
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${tournament.prizes.first.coins} coins',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatStartTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);

    if (diff.inDays > 0) {
      return 'in ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return 'in ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'in ${diff.inMinutes}m';
    } else {
      return 'Starting soon';
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Chip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Expected Output

- Tournament creation and management
- Multiple bracket formats (Single/Double Elimination, Round Robin, Swiss)
- Registration with entry fees
- Prize pool distribution
- Live bracket updates via Supabase Realtime
- Tournament chat
- Match scheduling and notifications
- Seeding and matchmaking
- Tournament history and statistics
