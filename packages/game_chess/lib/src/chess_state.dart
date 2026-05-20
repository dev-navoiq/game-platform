import 'package:equatable/equatable.dart';
import 'package:game_core/game_core.dart';

import 'chess_board.dart';
import 'chess_move.dart';
import 'chess_piece.dart';

// ---------------------------------------------------------------------------
// Castling rights
// ---------------------------------------------------------------------------

class CastlingRights extends Equatable {
  final bool whiteKingside;
  final bool whiteQueenside;
  final bool blackKingside;
  final bool blackQueenside;

  const CastlingRights({
    required this.whiteKingside,
    required this.whiteQueenside,
    required this.blackKingside,
    required this.blackQueenside,
  });

  factory CastlingRights.initial() => const CastlingRights(
        whiteKingside: true,
        whiteQueenside: true,
        blackKingside: true,
        blackQueenside: true,
      );

  CastlingRights copyWith({
    bool? whiteKingside,
    bool? whiteQueenside,
    bool? blackKingside,
    bool? blackQueenside,
  }) =>
      CastlingRights(
        whiteKingside: whiteKingside ?? this.whiteKingside,
        whiteQueenside: whiteQueenside ?? this.whiteQueenside,
        blackKingside: blackKingside ?? this.blackKingside,
        blackQueenside: blackQueenside ?? this.blackQueenside,
      );

  Map<String, dynamic> toJson() => {
        'whiteKingside': whiteKingside,
        'whiteQueenside': whiteQueenside,
        'blackKingside': blackKingside,
        'blackQueenside': blackQueenside,
      };

  factory CastlingRights.fromJson(Map<String, dynamic> json) => CastlingRights(
        whiteKingside: json['whiteKingside'] ?? true,
        whiteQueenside: json['whiteQueenside'] ?? true,
        blackKingside: json['blackKingside'] ?? true,
        blackQueenside: json['blackQueenside'] ?? true,
      );

  @override
  List<Object?> get props =>
      [whiteKingside, whiteQueenside, blackKingside, blackQueenside];
}

// ---------------------------------------------------------------------------
// Game result
// ---------------------------------------------------------------------------

enum ChessResultType { win, draw, abandoned }

class ChessResult extends Equatable {
  final String? winnerId;
  final ChessResultType type;
  final String reason;

  const ChessResult({
    this.winnerId,
    required this.type,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        if (winnerId != null) 'winnerId': winnerId,
        'type': type.name,
        'reason': reason,
      };

  @override
  List<Object?> get props => [winnerId, type, reason];
}

// ---------------------------------------------------------------------------
// Chess game state
// ---------------------------------------------------------------------------

class ChessState extends GameState {
  /// [0] = white player id, [1] = black player id.
  final List<String> playerIds;

  final ChessBoard board;
  final ChessColor activeColor;
  final CastlingRights castlingRights;
  final ChessSquare? enPassantSquare;

  /// Half-move clock for the 50-move rule (resets on pawn move or capture).
  final int halfmoveClock;
  final int fullmoveNumber;
  final List<ChessMove> moveHistory;

  /// FEN board string → occurrence count, used for threefold repetition.
  final Map<String, int> positionHistory;

  final ChessResult? result;

  @override
  final GamePhase phase;
  @override
  final int turnNumber;
  @override
  final int roundNumber;
  @override
  final RoomSocialMode socialMode;

  ChessState({
    required this.playerIds,
    required this.board,
    required this.activeColor,
    required this.castlingRights,
    this.enPassantSquare,
    this.halfmoveClock = 0,
    this.fullmoveNumber = 1,
    this.moveHistory = const [],
    this.positionHistory = const {},
    this.result,
    this.phase = GamePhase.playing,
    this.turnNumber = 1,
    this.roundNumber = 1,
    this.socialMode = RoomSocialMode.full,
  });

  factory ChessState.initial({
    required String whitePlayerId,
    required String blackPlayerId,
    RoomSocialMode socialMode = RoomSocialMode.full,
  }) =>
      ChessState(
        playerIds: [whitePlayerId, blackPlayerId],
        board: ChessBoard.initial(),
        activeColor: ChessColor.white,
        castlingRights: CastlingRights.initial(),
        socialMode: socialMode,
      );

  /// White = playerIds[0], black = playerIds[1].
  @override
  String get currentPlayerId =>
      activeColor == ChessColor.white ? playerIds[0] : playerIds[1];

  @override
  bool get isGameOver => result != null;

  ChessState copyWith({
    ChessBoard? board,
    ChessColor? activeColor,
    CastlingRights? castlingRights,
    ChessSquare? enPassantSquare,
    bool clearEnPassant = false,
    int? halfmoveClock,
    int? fullmoveNumber,
    List<ChessMove>? moveHistory,
    Map<String, int>? positionHistory,
    ChessResult? result,
    GamePhase? phase,
    int? turnNumber,
    RoomSocialMode? socialMode,
  }) =>
      ChessState(
        playerIds: playerIds,
        board: board ?? this.board,
        activeColor: activeColor ?? this.activeColor,
        castlingRights: castlingRights ?? this.castlingRights,
        enPassantSquare:
            clearEnPassant ? null : (enPassantSquare ?? this.enPassantSquare),
        halfmoveClock: halfmoveClock ?? this.halfmoveClock,
        fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
        moveHistory: moveHistory ?? this.moveHistory,
        positionHistory: positionHistory ?? this.positionHistory,
        result: result ?? this.result,
        phase: phase ?? this.phase,
        turnNumber: turnNumber ?? this.turnNumber,
        roundNumber: roundNumber,
        socialMode: socialMode ?? this.socialMode,
      );

  @override
  Map<String, dynamic> toJson() => {
        'playerIds': playerIds,
        'board': board.toFEN(),
        'activeColor': activeColor.name,
        'castlingRights': castlingRights.toJson(),
        if (enPassantSquare != null) 'enPassantSquare': enPassantSquare!.notation,
        'halfmoveClock': halfmoveClock,
        'fullmoveNumber': fullmoveNumber,
        'moveHistory': moveHistory.map((m) => m.toJson()).toList(),
        'positionHistory': positionHistory,
        if (result != null) 'result': result!.toJson(),
        'phase': phase.name,
        'turnNumber': turnNumber,
        'roundNumber': roundNumber,
        'socialMode': socialMode.name,
      };

  @override
  List<Object?> get props => [
        playerIds,
        board,
        activeColor,
        castlingRights,
        enPassantSquare,
        halfmoveClock,
        fullmoveNumber,
        moveHistory,
        result,
        phase,
        turnNumber,
        socialMode,
      ];
}
