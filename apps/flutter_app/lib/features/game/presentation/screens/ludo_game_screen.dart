import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../providers/game_provider.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../widgets/game_table.dart';
import '../widgets/ludo_board_widget.dart';
import '../widgets/ludo_dice_widget.dart';
import '../widgets/turn_timer.dart';

/// Ludo game screen with board, dice roll, and token movement.
class LudoGameScreen extends ConsumerStatefulWidget {
  final LudoState state;
  final String roomId;
  final String localPlayerId;

  const LudoGameScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.localPlayerId,
  });

  @override
  ConsumerState<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends ConsumerState<LudoGameScreen> {
  bool _isRolling = false;
  String? _selectedTokenId;

  bool get _isMyTurn =>
      widget.state.currentPlayerId == widget.localPlayerId;

  bool get _isSpectator =>
      !widget.state.playerIds.contains(widget.localPlayerId);

  bool get _needsToRoll =>
      _isMyTurn && widget.state.lastRoll == null;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final localColor = state.playerColors[widget.localPlayerId];

    // Determine which tokens are movable
    final movableTokenIds = <String>{};
    if (_isMyTurn && state.lastRoll != null && localColor != null) {
      for (final token in state.tokensFor(widget.localPlayerId)) {
        if (token.isFinished) continue;
        if (token.isAtHome && state.lastRoll == 6) {
          movableTokenIds.add(token.id);
        } else if (token.isInPlay) {
          movableTokenIds.add(token.id);
        }
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
                  gameName: 'Ludo',
                  socialMode: state.socialMode,
                  isSpectator: _isSpectator,
                ),
                const SizedBox(height: 4),

                // Current player indicator
                GlassContainer(
                  key: const Key('score-display'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ludoColorToFlutter(
                              state.playerColors[state.currentPlayerId]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isMyTurn ? 'Your Turn' : '${state.currentPlayerId}\'s Turn',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (state.lastRoll != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Rolled: ${state.lastRoll}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Board
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: LudoBoardWidget(
                          state: state,
                          selectedTokenId: _selectedTokenId,
                          movableTokenIds: movableTokenIds,
                          onTokenTap: _isMyTurn && !_isSpectator
                              ? _onTokenTap
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Dice + controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LudoDiceWidget(
                      value: state.lastRoll,
                      isRolling: _isRolling,
                      isEnabled: _needsToRoll && !_isSpectator,
                      onTap: _needsToRoll ? _rollDice : null,
                    ),
                    if (state.canRollAgain && _isMyTurn) ...[
                      const SizedBox(width: 12),
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Text(
                          'Roll Again!',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Turn timer
                if (_isMyTurn && !state.isGameOver)
                  const TurnTimer(seconds: 30),

                // Emoji bar
                EmojiBar(
                  onEmojiTap: (_) {},
                  socialMode: state.socialMode,
                  roomId: widget.roomId,
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GameActions(
                    isSpectator: _isSpectator,
                    onLeave: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: state.winnerId == widget.localPlayerId,
            winnerName: state.winnerId,
            coinsEarned: state.winnerId == widget.localPlayerId ? 50 : 10,
            xpEarned: state.winnerId == widget.localPlayerId ? 30 : 10,
            onDoubleCoins: () {
              RewardedAdModal.show(context: context);
            },
            onPlayAgain: () {},
            onLeave: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  void _rollDice() {
    setState(() => _isRolling = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isRolling = false);
      ref.read(gameStateProvider.notifier).sendMove(
        roomId: widget.roomId,
        move: {
          'type': 'roll',
          'player_id': widget.localPlayerId,
        },
      );
    });
  }

  void _onTokenTap(String tokenId) {
    if (_selectedTokenId == tokenId) {
      // Second tap — move the token
      ref.read(gameStateProvider.notifier).sendMove(
        roomId: widget.roomId,
        move: {
          'type': 'move',
          'player_id': widget.localPlayerId,
          'token_id': tokenId,
        },
      );
      setState(() => _selectedTokenId = null);
    } else {
      setState(() => _selectedTokenId = tokenId);
    }
  }

  Color _ludoColorToFlutter(LudoColor? color) {
    switch (color) {
      case LudoColor.red:
        return AppColors.player1;
      case LudoColor.blue:
        return AppColors.player2;
      case LudoColor.green:
        return AppColors.player3;
      case LudoColor.yellow:
        return AppColors.player4;
      case null:
        return AppColors.textMuted;
    }
  }
}
