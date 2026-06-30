import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_chess/game_chess.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../providers/game_provider.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../widgets/game_table.dart';
import '../widgets/turn_timer.dart';

/// Chess game screen with board, move history, and promotion dialog.
class ChessGameScreen extends ConsumerStatefulWidget {
  final ChessState state;
  final String roomId;
  final String localPlayerId;

  const ChessGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  ConsumerState<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends ConsumerState<ChessGameScreen> {
  ChessSquare? _selectedSquare;
  Set<ChessSquare> _validMoves = {};

  ChessColor get _localColor {
    if (widget.state.playerIds.isEmpty) return ChessColor.white;
    return widget.state.playerIds[0] == widget.localPlayerId
        ? ChessColor.white
        : ChessColor.black;
  }

  bool get _isMyTurn =>
      widget.state.currentPlayerId == widget.localPlayerId;

  bool get _isSpectator =>
      !widget.state.playerIds.contains(widget.localPlayerId);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final flipBoard = _localColor == ChessColor.black;

    // Last move highlights
    ChessSquare? lastFrom, lastTo;
    if (state.moveHistory.isNotEmpty) {
      final lastMove = state.moveHistory.last;
      if (lastMove is ChessMoveAction) {
        lastFrom = lastMove.from;
        lastTo = lastMove.to;
      }
    }

    return Stack(
      children: [
        GameTable(
          child: SafeArea(
            child: Column(
              children: [
                // HUD
                GameHud(
                  gameName: 'Chess',
                  socialMode: state.socialMode,
                  isSpectator: _isSpectator,
                  onForfeitTap: () => confirmAndForfeitGame(
                    context,
                    ref,
                    isSpectator: _isSpectator,
                  ),
                ),
                const SizedBox(height: 4),

                // Status bar
                GlassContainer(
                  key: const Key('score-display'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.activeColor == ChessColor.white
                            ? '⬜ White to move'
                            : '⬛ Black to move',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (state.result != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          state.result!.reason,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Chess board
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ChessBoardWidget(
                          board: state.board,
                          selectedSquare: _selectedSquare,
                          validMoveSquares: _validMoves,
                          lastMoveFrom: lastFrom,
                          lastMoveTo: lastTo,
                          flipBoard: flipBoard,
                          onSquareTap: _isMyTurn && !_isSpectator
                              ? _onSquareTap
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Move history
                if (state.moveHistory.isNotEmpty)
                  SizedBox(
                    height: 28,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.moveHistory.length,
                      itemBuilder: (context, i) {
                        final move = state.moveHistory[i];
                        final notation = move is ChessMoveAction
                            ? '${move.from}${move.to}'
                            : 'resign';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(
                              '${(i ~/ 2) + 1}.${i % 2 == 0 ? '' : '..'}$notation',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 4),

                // Turn timer
                if (_isMyTurn && !state.isGameOver)
                  const TurnTimer(seconds: 120),

                // Emoji bar
                EmojiBar(
                  onEmojiTap: (_) {},
                  socialMode: state.socialMode,
                  roomId: widget.roomId,
                ),

                // Actions
              ],
            ),
          ),
        ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: state.result?.winnerId == widget.localPlayerId,
            winnerName: state.result?.winnerId,
            finalScores: {},
            coinsEarned: state.result?.winnerId == widget.localPlayerId ? 50 : 10,
            xpEarned: state.result?.winnerId == widget.localPlayerId ? 30 : 10,
            onDoubleCoins: () {
              RewardedAdModal.show(context: context);
            },
            onPlayAgain: () {},
            onLeave: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  void _onSquareTap(ChessSquare square) {
    final state = widget.state;

    if (_selectedSquare != null && _validMoves.contains(square)) {
      // Make the move
      final piece = state.board.pieceAt(_selectedSquare!);
      // Check for pawn promotion
      if (piece != null &&
          piece.type == ChessPieceType.pawn &&
          (square.rank == 0 || square.rank == 7)) {
        _showPromotionDialog(square);
        return;
      }

      _makeMove(_selectedSquare!, square);
      return;
    }

    // Select a piece
    final piece = state.board.pieceAt(square);
    if (piece != null && piece.color == state.activeColor) {
      setState(() {
        _selectedSquare = square;
        // Calculate valid moves for this piece (simplified — show all squares for now)
        _validMoves = _getValidSquaresForPiece(square);
      });
    } else {
      setState(() {
        _selectedSquare = null;
        _validMoves = {};
      });
    }
  }

  Set<ChessSquare> _getValidSquaresForPiece(ChessSquare from) {
    // In a full implementation, use ChessRules.getValidMoves().
    // For now, show all empty squares and opponent pieces as potential targets.
    final validSquares = <ChessSquare>{};
    final piece = widget.state.board.pieceAt(from);
    if (piece == null) return validSquares;

    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final sq = ChessSquare(file, rank);
        if (sq == from) continue;
        final target = widget.state.board.pieceAt(sq);
        if (target == null || target.color != piece.color) {
          validSquares.add(sq);
        }
      }
    }
    return validSquares;
  }

  void _makeMove(ChessSquare from, ChessSquare to, {ChessPieceType? promotion}) {
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': promotion != null ? 'promote' : 'movePiece',
        'playerId': widget.localPlayerId,
        'from': from.notation,
        'to': to.notation,
        if (promotion != null) 'promotion': promotion.name,
      },
    );
    setState(() {
      _selectedSquare = null;
      _validMoves = {};
    });
  }

  Future<void> _showPromotionDialog(ChessSquare to) async {
    final selected = await showDialog<ChessPieceType>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.feltMid,
        title: Text(
          'Promote Pawn',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ChessPieceType.queen,
            ChessPieceType.rook,
            ChessPieceType.bishop,
            ChessPieceType.knight,
          ].map((type) {
            final piece = ChessPiece(type: type, color: _localColor);
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, type),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    piece.symbol,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && _selectedSquare != null) {
      _makeMove(_selectedSquare!, to, promotion: selected);
    }
  }
}
