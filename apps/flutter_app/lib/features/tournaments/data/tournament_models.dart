import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum TournamentFormat {
  singleElimination('single_elimination', 'Single Elimination'),
  doubleElimination('double_elimination', 'Double Elimination'),
  roundRobin('round_robin', 'Round Robin'),
  swiss('swiss', 'Swiss'),
  multiStage('multi_stage', 'Multi-Stage');

  final String dbValue;
  final String displayName;
  const TournamentFormat(this.dbValue, this.displayName);

  static TournamentFormat fromDb(String value) {
    return TournamentFormat.values.firstWhere((f) => f.dbValue == value);
  }
}

enum TournamentStatus {
  draft('draft'),
  registration('registration'),
  starting('starting'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String dbValue;
  const TournamentStatus(this.dbValue);

  static TournamentStatus fromDb(String value) {
    return TournamentStatus.values.firstWhere((s) => s.dbValue == value);
  }
}

enum BracketSide {
  winners('winners'),
  losers('losers'),
  finals('finals');

  final String dbValue;
  const BracketSide(this.dbValue);

  static BracketSide fromDb(String value) {
    return BracketSide.values.firstWhere((s) => s.dbValue == value);
  }
}

enum ParticipantStatus {
  registered('registered'),
  checkedIn('checked_in'),
  active('active'),
  eliminated('eliminated'),
  winner('winner');

  final String dbValue;
  const ParticipantStatus(this.dbValue);

  static ParticipantStatus fromDb(String value) {
    return ParticipantStatus.values.firstWhere((s) => s.dbValue == value);
  }
}

enum MatchStatus {
  pending('pending'),
  ready('ready'),
  inProgress('in_progress'),
  completed('completed'),
  bye('bye');

  final String dbValue;
  const MatchStatus(this.dbValue);

  static MatchStatus fromDb(String value) {
    return MatchStatus.values.firstWhere((s) => s.dbValue == value);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class TournamentPrize extends Equatable {
  final int place;
  final int coins;
  final int gems;
  final String? skinId;
  final String? title;

  const TournamentPrize({
    required this.place,
    this.coins = 0,
    this.gems = 0,
    this.skinId,
    this.title,
  });

  factory TournamentPrize.fromJson(Map<String, dynamic> json) {
    return TournamentPrize(
      place: json['place'] as int,
      coins: (json['coins'] as int?) ?? 0,
      gems: (json['gems'] as int?) ?? 0,
      skinId: json['skin_id'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'place': place,
        'coins': coins,
        'gems': gems,
        if (skinId != null) 'skin_id': skinId,
        if (title != null) 'title': title,
      };

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

  @override
  List<Object?> get props => [place, coins, gems, skinId, title];
}

class Tournament extends Equatable {
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
  final Map<String, dynamic> settings;
  final TournamentStatus status;
  final String? winnerId;
  final Map<String, dynamic>? finalStandings;
  final String minSubscriptionTier;
  final String roomSocialMode;
  final int teamSize;
  final bool allowSoloPairing;
  final DateTime createdAt;

  const Tournament({
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
    this.settings = const {},
    this.status = TournamentStatus.draft,
    this.winnerId,
    this.finalStandings,
    this.minSubscriptionTier = 'free',
    this.roomSocialMode = 'focus',
    this.teamSize = 1,
    this.allowSoloPairing = false,
    required this.createdAt,
  });

  bool get isTeamTournament => teamSize > 1;
  bool get isFree => entryFeeCoins == 0 && entryFeeGems == 0;
  bool get isFull => currentParticipants >= maxParticipants;
  bool get isRegistrationOpen =>
      status == TournamentStatus.registration &&
      !isFull &&
      (registrationEnd == null || DateTime.now().isBefore(registrationEnd!));
  bool get isLive => status == TournamentStatus.inProgress;
  bool get isCompleted => status == TournamentStatus.completed;

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      gameType: json['game_type'] as String,
      format: TournamentFormat.fromDb(json['format'] as String),
      organizerId: json['organizer_id'] as String?,
      isOfficial: (json['is_official'] as bool?) ?? false,
      registrationStart: json['registration_start'] != null
          ? DateTime.parse(json['registration_start'] as String)
          : null,
      registrationEnd: json['registration_end'] != null
          ? DateTime.parse(json['registration_end'] as String)
          : null,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      minParticipants: json['min_participants'] as int,
      maxParticipants: json['max_participants'] as int,
      currentParticipants: (json['current_participants'] as int?) ?? 0,
      entryFeeCoins: (json['entry_fee_coins'] as int?) ?? 0,
      entryFeeGems: (json['entry_fee_gems'] as int?) ?? 0,
      prizes: (json['prize_pool'] as List<dynamic>?)
              ?.map((p) =>
                  TournamentPrize.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      status: TournamentStatus.fromDb(json['status'] as String),
      winnerId: json['winner_id'] as String?,
      finalStandings: json['final_standings'] as Map<String, dynamic>?,
      minSubscriptionTier:
          (json['min_subscription_tier'] as String?) ?? 'free',
      roomSocialMode: (json['room_social_mode'] as String?) ?? 'focus',
      teamSize: (json['team_size'] as int?) ?? 1,
      allowSoloPairing: (json['allow_solo_pairing'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id];
}

class TournamentParticipant extends Equatable {
  final String id;
  final String tournamentId;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String? teamId;
  final ParticipantStatus status;
  final int? seed;
  final int currentRound;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final int gameWins;
  final double buchholz;
  final DateTime registeredAt;
  final DateTime? checkedInAt;
  final DateTime? eliminatedAt;

  const TournamentParticipant({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.username,
    this.avatarUrl,
    this.teamId,
    this.status = ParticipantStatus.registered,
    this.seed,
    this.currentRound = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    this.gameWins = 0,
    this.buchholz = 0,
    required this.registeredAt,
    this.checkedInAt,
    this.eliminatedAt,
  });

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) {
    return TournamentParticipant(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      userId: json['user_id'] as String,
      username: json['profile']?['username'] as String? ??
          json['username'] as String?,
      avatarUrl: json['profile']?['avatar_url'] as String? ??
          json['avatar_url'] as String?,
      teamId: json['team_id'] as String?,
      status: ParticipantStatus.fromDb(json['status'] as String),
      seed: json['seed'] as int?,
      currentRound: (json['current_round'] as int?) ?? 0,
      wins: (json['wins'] as int?) ?? 0,
      losses: (json['losses'] as int?) ?? 0,
      draws: (json['draws'] as int?) ?? 0,
      points: (json['points'] as int?) ?? 0,
      gameWins: (json['game_wins'] as int?) ?? 0,
      buchholz: (json['buchholz'] as num?)?.toDouble() ?? 0,
      registeredAt: json['registered_at'] != null
          ? DateTime.parse(json['registered_at'] as String)
          : DateTime.now(),
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
      eliminatedAt: json['eliminated_at'] != null
          ? DateTime.parse(json['eliminated_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id];
}

class TournamentMatch extends Equatable {
  final String id;
  final String tournamentId;
  final int round;
  final int matchNumber;
  final BracketSide bracketSide;
  final String? player1Id;
  final String? player2Id;
  final String? player1Name;
  final String? player2Name;
  final String? player1AvatarUrl;
  final String? player2AvatarUrl;
  final int? player1Seed;
  final int? player2Seed;
  final String? winnerId;
  final int? player1Score;
  final int? player2Score;
  final Map<String, dynamic>? resultDetails;
  final String? roomId;
  final MatchStatus status;
  final DateTime? scheduledTime;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? nextMatchId;
  final int? nextMatchSlot;
  final String? loserNextMatchId;

  const TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchNumber,
    required this.bracketSide,
    this.player1Id,
    this.player2Id,
    this.player1Name,
    this.player2Name,
    this.player1AvatarUrl,
    this.player2AvatarUrl,
    this.player1Seed,
    this.player2Seed,
    this.winnerId,
    this.player1Score,
    this.player2Score,
    this.resultDetails,
    this.roomId,
    this.status = MatchStatus.pending,
    this.scheduledTime,
    this.startedAt,
    this.completedAt,
    this.nextMatchId,
    this.nextMatchSlot,
    this.loserNextMatchId,
  });

  bool get isBye => status == MatchStatus.bye;
  bool get isCompleted => status == MatchStatus.completed;
  bool get isReady =>
      status == MatchStatus.ready && player1Id != null && player2Id != null;
  bool get isLive => status == MatchStatus.inProgress;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      round: json['round'] as int,
      matchNumber: json['match_number'] as int,
      bracketSide: BracketSide.fromDb(json['bracket_side'] as String),
      player1Id: json['player1_id'] as String?,
      player2Id: json['player2_id'] as String?,
      player1Name: json['player1']?['username'] as String?,
      player2Name: json['player2']?['username'] as String?,
      player1AvatarUrl: json['player1']?['avatar_url'] as String?,
      player2AvatarUrl: json['player2']?['avatar_url'] as String?,
      player1Seed: json['player1_seed'] as int?,
      player2Seed: json['player2_seed'] as int?,
      winnerId: json['winner_id'] as String?,
      player1Score: json['player1_score'] as int?,
      player2Score: json['player2_score'] as int?,
      resultDetails: json['result_details'] as Map<String, dynamic>?,
      roomId: json['room_id'] as String?,
      status: MatchStatus.fromDb(json['status'] as String),
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      nextMatchId: json['next_match_id'] as String?,
      nextMatchSlot: json['next_match_slot'] as int?,
      loserNextMatchId: json['loser_next_match_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

class TournamentChatMessage extends Equatable {
  final String id;
  final String tournamentId;
  final String senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String content;
  final bool isAnnouncement;
  final DateTime createdAt;

  const TournamentChatMessage({
    required this.id,
    required this.tournamentId,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.isAnnouncement = false,
    required this.createdAt,
  });

  factory TournamentChatMessage.fromJson(Map<String, dynamic> json) {
    return TournamentChatMessage(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender']?['username'] as String?,
      senderAvatarUrl: json['sender']?['avatar_url'] as String?,
      content: json['content'] as String,
      isAnnouncement: (json['is_announcement'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id];
}

enum TournamentRegistrationResult {
  success,
  tournamentNotFound,
  registrationClosed,
  alreadyRegistered,
  tournamentFull,
  insufficientFunds,
  tierRequired,
  teamRequired,
  teamFull,
  teamNotFound,
  error,
}

// ── Teams (2v2 tournaments) ──────────────────────────────────────────────────

class TournamentTeam extends Equatable {
  final String id;
  final String tournamentId;
  final String captainId;
  final String? name;
  final List<TournamentParticipant> members;

  const TournamentTeam({
    required this.id,
    required this.tournamentId,
    required this.captainId,
    this.name,
    this.members = const [],
  });

  bool get isOpen => members.length < 2;
  String get displayName =>
      name ??
      (members.isNotEmpty
          ? "${members.first.username ?? 'Team'}'s team"
          : 'Team');

  factory TournamentTeam.fromJson(
    Map<String, dynamic> json, {
    List<TournamentParticipant> members = const [],
  }) {
    return TournamentTeam(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      captainId: json['captain_id'] as String,
      name: json['name'] as String?,
      members: members,
    );
  }

  @override
  List<Object?> get props => [id, members];
}
