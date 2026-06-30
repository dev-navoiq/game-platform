import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_session_providers.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/game_actions.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_over_dialog.dart';
import '../../../../shared/widgets/rewarded_ad_modal.dart';
import '../../../../shared/animations/celebrations/confetti_animation.dart';
import '../widgets/game_table.dart';
import '../ludo/ludo_animated_board.dart';
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
  final _rules = LudoRules();
  bool _isRolling = false;
  int? _autoPassedForTurn;

  bool get _isMyTurn =>
      widget.state.currentPlayerId == widget.localPlayerId;

  bool get _isSpectator =>
      !widget.state.playerIds.contains(widget.localPlayerId);

  bool get _needsToRoll =>
      _isMyTurn && widget.state.lastRoll == null;

  /// Resolve a player id to a display name via the room roster, falling back
  /// to a seat label so the UI never shows a raw UUID.
  String _nameFor(String? playerId) {
    if (playerId == null) return 'Player';
    final members = ref.read(roomMembersProvider);
    final name = members[playerId]?.displayName;
    if (name != null && name.isNotEmpty) return name;
    final seat = widget.state.playerIds.indexOf(playerId);
    return seat >= 0 ? 'Player ${seat + 1}' : 'Player';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    // Ask the engine exactly which moves are legal right now — this handles
    // overshoot, exact-finish and the "no moves left → must pass" case that a
    // naive isAtHome/isInPlay check would get wrong.
    final validMoves = (_isMyTurn && !_isSpectator && !state.isGameOver)
        ? _rules.getValidMoves(state, widget.localPlayerId)
        : const <LudoMove>[];
    final movableTokenIds =
        validMoves.whereType<LudoMoveToken>().map((m) => m.tokenId).toSet();
    final mustPass = validMoves.length == 1 && validMoves.first is LudoPass;

    // No legal token move after a roll → auto-pass so the turn advances. There
    // is no manual pass button, so a stuck turn would otherwise soft-lock.
    if (mustPass) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPass(state));
    }

    // The player rolls the dice themselves (tap). Show the countdown whenever
    // an action is pending — either to roll, or to choose a token to move.
    final showTimer = _isMyTurn &&
        !_isSpectator &&
        !state.isGameOver &&
        (_needsToRoll || movableTokenIds.isNotEmpty);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      children: [
        GameTable(
          child: SafeArea(
            child: isLandscape
                ? _buildLandscape(state, movableTokenIds, showTimer)
                : _buildPortrait(state, movableTokenIds, showTimer),
          ),
        ),

        // Celebration burst when the game finishes (everyone home).
        if (state.isGameOver)
          const Positioned.fill(
            child: IgnorePointer(
              child: ConfettiAnimation(isPlaying: true, particleCount: 160),
            ),
          ),

        // Game over
        if (state.isGameOver)
          GameOverDialog(
            isWinner: state.winnerId == widget.localPlayerId,
            winnerName: _nameFor(state.winnerId),
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

  // ── Layout pieces (shared by portrait + landscape) ──────────────────────────

  /// Quarter-turns to rotate the board so the LOCAL player's home is always at
  /// the bottom-left, whatever color they were dealt.
  int _localQuarterTurns(LudoState state) {
    switch (state.playerColors[widget.localPlayerId]) {
      case LudoColor.red:
        return 0; // already bottom-left
      case LudoColor.yellow:
        return 1; // bottom-right → bottom-left
      case LudoColor.green:
        return 2; // top-right → bottom-left
      case LudoColor.blue:
        return 3; // top-left → bottom-left
      case null:
        return 0;
    }
  }

  Widget _hud(LudoState state) => GameHud(
        gameName: 'Ludo',
        socialMode: state.socialMode,
        isSpectator: _isSpectator,
        onForfeitTap: () =>
            confirmAndForfeitGame(context, ref, isSpectator: _isSpectator),
      );

  Widget _turnPill(LudoState state) => GlassContainer(
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
              _isMyTurn
                  ? 'Your Turn'
                  : '${_nameFor(state.currentPlayerId)}\'s Turn',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            if (state.lastRoll != null) ...[
              const SizedBox(width: 8),
              Text(
                'Rolled ${state.lastRoll}',
                style:
                    GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      );

  Widget _timerSlot(bool showTimer) => SizedBox(
        width: 40,
        height: 40,
        child: showTimer ? const TurnTimer(seconds: 30) : null,
      );

  Widget _board(LudoState state, Set<String> movable, {double maxSize = 520}) =>
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSize, maxHeight: maxSize),
          child: RotatedBox(
            quarterTurns: _localQuarterTurns(state),
            child: LudoAnimatedBoard(
              state: state,
              movableTokenIds: movable,
              onTokenTap:
                  _isMyTurn && !_isSpectator ? _onTokenTap : null,
            ),
          ),
        ),
      );

  Widget _diceRow(LudoState state) {
    final canRoll = _needsToRoll && !_isSpectator;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LudoDiceWidget(
              value: state.lastRoll,
              isRolling: _isRolling,
              isEnabled: canRoll,
              onTap: canRoll ? _rollDice : null,
            ),
            if (state.canRollAgain && _isMyTurn) ...[
              const SizedBox(width: 12),
              GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        // Reserved height so the hint never reflows the layout.
        SizedBox(
          height: 18,
          child: canRoll && !_isRolling
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap to roll',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _emoji(LudoState state) => EmojiBar(
        onEmojiTap: (_) {},
        socialMode: state.socialMode,
        roomId: widget.roomId,
      );

  Widget _buildPortrait(
      LudoState state, Set<String> movable, bool showTimer) {
    return Column(
      children: [
        _hud(state),
        const SizedBox(height: 4),
        SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _turnPill(state),
              const SizedBox(width: 10),
              _timerSlot(showTimer),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _board(state, movable),
          ),
        ),
        const SizedBox(height: 8),
        _diceRow(state),
        const SizedBox(height: 8),
        _emoji(state),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLandscape(
      LudoState state, Set<String> movable, bool showTimer) {
    return Column(
      children: [
        _hud(state),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _board(state, movable, maxSize: 900),
                ),
              ),
              SizedBox(
                width: 210,
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 8, top: 4, bottom: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _turnPill(state),
                      const SizedBox(height: 14),
                      SizedBox(
                          height: 44,
                          child: Center(child: _timerSlot(showTimer))),
                      const SizedBox(height: 18),
                      _diceRow(state),
                      const Spacer(),
                      _emoji(state),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  void _autoPass(LudoState state) {
    if (!mounted) return;
    if (_autoPassedForTurn == state.turnNumber) return; // already sent
    _autoPassedForTurn = state.turnNumber;
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {'type': 'pass', 'player_id': widget.localPlayerId},
    );
  }

  void _onTokenTap(String tokenId) {
    // Single tap moves the tapped token immediately (no select-then-confirm).
    ref.read(gameStateProvider.notifier).sendMove(
      roomId: widget.roomId,
      move: {
        'type': 'move',
        'player_id': widget.localPlayerId,
        'token_id': tokenId,
      },
    );
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
