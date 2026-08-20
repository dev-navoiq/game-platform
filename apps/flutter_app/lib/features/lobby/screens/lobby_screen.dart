import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/live_games_provider.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_bottom_sheet.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../game/local/practice_launcher.dart';
import '../models/game_player_limits.dart';
import '../models/room_member.dart';
import '../presentation/widgets/room_list_card.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String gameType;

  const LobbyScreen({super.key, this.gameType = ''});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  /// Guards against a double-tap pushing two Room screens (→ two rooms). Held
  /// while the Room screen is on top; cleared when the user returns here, so a
  /// second create is allowed after backing out.
  bool _navigating = false;

  String _displayName(AppLocalizations l10n) {
    switch (widget.gameType) {
      case 'twenty_nine':
        return l10n.gameNameTwentyNine;
      case 'oh_hell':
        return l10n.gameNameOhHell;
      case 'hearts':
        return l10n.gameNameHearts;
      case 'spades':
        return l10n.gameNameSpades;
      case 'bridge':
        return l10n.gameNameBridge;
      case 'chess':
        return l10n.gameNameChess;
      case 'ludo':
        return l10n.gameNameLudo;
      case 'sequence':
        return l10n.gameNameSequence;
      default:
        return l10n.gameNameGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // #285 launch-gate backstop: a sealed game's lobby can still be reached
    // by deep link or stale navigation — show Coming soon instead of the
    // create/join surface. (The server rejects create-room too.)
    if (!ref.watch(isGameLiveProvider(widget.gameType))) {
      return FeltBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: GlassAppBar(title: _displayName(l10n)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_clock,
                      size: 56, color: AppColors.textFeltMuted),
                  const SizedBox(height: 16),
                  Text(
                    '${_displayName(l10n)} is coming soon!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnFelt,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We\'re polishing this game for launch. Stay tuned!',
                    style: TextStyle(color: AppColors.textFeltMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: l10n.lobbyTitle(_displayName(l10n))),
        body: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            children: [
              // Join by Code button — opens the join screen
              GlassButton(
                label: l10n.joinByCode,
                onPressed: () => context.push(AppRoutes.joinByCodePath(widget.gameType)),
                size: GlassButtonSize.large,
                width: double.infinity,
                variant: GlassButtonVariant.outlined,
                icon: const Icon(Icons.vpn_key_outlined,
                    color: Colors.white, size: 20),
              ),

              // Practice vs Bots — fully on-device game, no room/server needed.
              if (practiceSupportedGameTypes.contains(widget.gameType)) ...[
                const SizedBox(height: 12),
                GlassButton(
                  label: l10n.practiceVsBots,
                  onPressed: () =>
                      startPracticeVsBots(context, ref, gameType: widget.gameType),
                  size: GlassButtonSize.large,
                  width: double.infinity,
                  variant: GlassButtonVariant.outlined,
                  icon: const Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 20),
                ),
              ],
              const SizedBox(height: 16),

              // Room list (placeholder — sample rooms until matchmaking is wired)
              Expanded(
                child: _RoomList(gameType: widget.gameType),
              ),

              // Banner ad (free tier only)
              const BannerAdWidget(),

              // Create Room button — navigates straight to the room, which
              // creates itself in the background so the user never waits on a
              // frozen button.
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: GlassButton(
                  label: l10n.createRoom,
                  onPressed: _onCreateRoom,
                  size: GlassButtonSize.large,
                  width: double.infinity,
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCreateRoom() async {
    if (_navigating) return;

    // Ask up front for the things the server needs at create time: seat
    // count (variable-player games), game-length options (Oh Hell), and
    // auto-start. Everything else is decided inside the room. Fixed-seat
    // games without extra options skip the sheet entirely — that includes
    // 2-player Chess, which the old hardcoded maxPlayers=4 kept broken.
    final opts = await _showCreateOptionsSheet(context);
    if (opts == null || !mounted) return; // dismissed

    // Navigate immediately with a create request; the Room screen renders an
    // optimistic "creating…" table and fires create-room in the background.
    // `push` resolves when the user returns, so we can re-arm the guard.
    _navigating = true;
    await context.push(
      AppRoutes.roomPath(AppRoutes.pendingRoomId),
      extra: RoomCreateRequest(
        gameType: widget.gameType,
        socialMode: 'full',
        maxPlayers: opts.maxPlayers,
        config: opts.config,
      ),
    );
    if (mounted) _navigating = false;
  }

  Future<RoomCreateOptions?> _showCreateOptionsSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPlayerChoice = GamePlayerLimits.isVariable(widget.gameType);
    final hasLengthChoice = widget.gameType == 'oh_hell';

    if (!hasPlayerChoice && !hasLengthChoice) {
      // Nothing to ask — still offer the auto-start toggle? No: keep the
      // fast path fast. Fixed games start via the host button.
      return Future.value(RoomCreateOptions(
        maxPlayers: GamePlayerLimits.maxFor(widget.gameType),
        config: null,
      ));
    }

    return GlassBottomSheet.show<RoomCreateOptions>(
      context: context,
      title: hasPlayerChoice ? l10n.howManyPlayers : l10n.gameLength,
      child: _CreateRoomOptionsSheet(gameType: widget.gameType),
    );
  }
}

/// What the create sheet hands back: seat count plus the room-config JSON
/// (Oh Hell length options, auto-start flag) forwarded to create-room.
class RoomCreateOptions {
  final int maxPlayers;
  final Map<String, dynamic>? config;

  const RoomCreateOptions({required this.maxPlayers, this.config});
}

enum _GameLengthPreset { quick, oneWay, classic }

/// Body of the pre-create options sheet: player-count chips for
/// variable-seat games, game-length presets for Oh Hell (with live round
/// counts that track the selected player count), and an auto-start toggle.
class _CreateRoomOptionsSheet extends StatefulWidget {
  final String gameType;

  const _CreateRoomOptionsSheet({required this.gameType});

  @override
  State<_CreateRoomOptionsSheet> createState() =>
      _CreateRoomOptionsSheetState();
}

class _CreateRoomOptionsSheetState extends State<_CreateRoomOptionsSheet> {
  late int _players = GamePlayerLimits.maxFor(widget.gameType) ==
          GamePlayerLimits.minFor(widget.gameType)
      ? GamePlayerLimits.maxFor(widget.gameType)
      : GamePlayerLimits.minFor(widget.gameType);
  _GameLengthPreset _length = _GameLengthPreset.classic;
  bool _autoStart = false;

  bool get _hasPlayerChoice => GamePlayerLimits.isVariable(widget.gameType);
  bool get _hasLengthChoice => widget.gameType == 'oh_hell';

  /// Rounds for an Oh Hell preset at the current player count. Mirrors
  /// OhHellConfig.roundSequence: down-and-up = 2m-1 rounds, one-way = m.
  int _roundsFor(_GameLengthPreset preset) {
    final deckMax = 52 ~/ _players;
    switch (preset) {
      case _GameLengthPreset.quick:
        final m = deckMax < 5 ? deckMax : 5;
        return 2 * m - 1;
      case _GameLengthPreset.oneWay:
        return deckMax;
      case _GameLengthPreset.classic:
        return 2 * deckMax - 1;
    }
  }

  Map<String, dynamic>? _buildConfig() {
    final config = <String, dynamic>{};
    if (_hasLengthChoice) {
      switch (_length) {
        case _GameLengthPreset.quick:
          config['oh_hell'] = {'max_cards': 5};
        case _GameLengthPreset.oneWay:
          config['oh_hell'] = {'down_only': true};
        case _GameLengthPreset.classic:
          break; // engine default
      }
    }
    if (_autoStart) config['auto_start_when_full'] = true;
    return config.isEmpty ? null : config;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final min = GamePlayerLimits.minFor(widget.gameType);
    final max = GamePlayerLimits.maxFor(widget.gameType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.gameType == 'oh_hell'
                ? l10n.ohHellPlayerCountHint
                : l10n.playerCountHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (_hasPlayerChoice) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var n = min; n <= max; n++)
                  _PlayerCountChoice(
                    count: n,
                    selected: n == _players,
                    onTap: () => setState(() => _players = n),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_hasLengthChoice) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.gameLength,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (preset, label) in [
                  (_GameLengthPreset.quick, l10n.gameLengthQuick),
                  (_GameLengthPreset.oneWay, l10n.gameLengthOneWay),
                  (_GameLengthPreset.classic, l10n.gameLengthClassic),
                ])
                  _GameLengthChoice(
                    label: label,
                    rounds: l10n.roundsCount(_roundsFor(preset)),
                    selected: preset == _length,
                    onTap: () => setState(() => _length = preset),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              l10n.startWhenFull,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
            activeColor: AppColors.accent,
            value: _autoStart,
            onChanged: (v) => setState(() => _autoStart = v),
          ),
          const SizedBox(height: 8),
          GlassButton(
            label: AppLocalizations.of(context).createRoom,
            width: double.infinity,
            onPressed: () => Navigator.of(context).pop(
              RoomCreateOptions(
                maxPlayers: _players,
                config: _buildConfig(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameLengthChoice extends StatelessWidget {
  final String label;
  final String rounds;
  final bool selected;
  final VoidCallback onTap;

  const _GameLengthChoice({
    required this.label,
    required this.rounds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(selected ? 0.22 : 0.08),
          border: Border.all(
            color: AppColors.accent.withOpacity(selected ? 0.9 : 0.3),
            width: selected ? 1.6 : 1.1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              rounds,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCountChoice extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerCountChoice({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(selected ? 0.22 : 0.08),
          border: Border.all(
            color: AppColors.accent.withOpacity(selected ? 0.9 : 0.3),
            width: selected ? 1.6 : 1.2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppLocalizations.of(context).players,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder room list — shows sample rooms until real data is wired.
class _RoomList extends StatelessWidget {
  final String gameType;

  const _RoomList({required this.gameType});

  @override
  Widget build(BuildContext context) {
    // Placeholder rooms for visual demo
    final sampleRooms = [
      _SampleRoom('ABC123', 'Player1', 2, 4, 'full'),
      _SampleRoom('XYZ789', 'CardShark', 3, 4, 'chat_only'),
      _SampleRoom('QWE456', 'GameMaster', 1, 4, 'silent'),
    ];

    return ListView.separated(
      itemCount: sampleRooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final room = sampleRooms[index];
        return RoomListCard(
          roomCode: room.code,
          hostName: room.host,
          playerCount: room.players,
          maxPlayers: room.maxPlayers,
          socialMode: room.socialMode,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)
                      .roomJoinComingSoon(room.code))),
            );
          },
        );
      },
    );
  }
}

class _SampleRoom {
  final String code;
  final String host;
  final int players;
  final int maxPlayers;
  final String socialMode;

  const _SampleRoom(this.code, this.host, this.players, this.maxPlayers, this.socialMode);
}
