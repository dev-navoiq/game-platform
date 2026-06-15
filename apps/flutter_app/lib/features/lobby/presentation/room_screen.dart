import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_bottom_sheet.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../game/providers/bot_move_controller.dart';
import '../../game/providers/game_provider.dart';
import '../../game/providers/game_session_providers.dart';
import '../models/room_member.dart';
import 'widgets/player_slot_widget.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  List<RoomMember> _members = const [];
  String _socialMode = 'full';
  String? _gameType;
  // Sourced from the room's max_players column. Drives the seat-slot grid
  // and the bot-add limit (was hardcoded to 4 → could only add 4 bots even
  // in a 7-player Oh Hell room).
  int _maxPlayers = 4;
  bool _isReady = false;
  bool _isStarting = false;
  bool _isAddingBot = false;
  String? _roomCode;
  void Function()? _disposeMembershipSub;

  /// Minimum number of seats that must be filled before the host can start.
  /// Default 2 for unknown / 2-player games (chess, sequence). Card games
  /// that need fixed-or-minimum tables override here.
  int get _minPlayersForGame {
    switch (_gameType) {
      case 'twenty_nine':
      case 'hearts':
      case 'spades':
      case 'bridge':
      case 'oh_hell':
        return 4;
      case 'ludo':
        return 2;
      case 'chess':
      case 'sequence':
      default:
        return 2;
    }
  }
  // Guard against re-navigating after the room status flips to 'playing'.
  // Without this the membership subscription would push the game route
  // every time it fires (host included, since their room screen stays
  // mounted under the pushed game route).
  bool _navigatedToGame = false;

  /// Whether the local user is the host of this room.
  /// `_members` is populated by the snapshot — until it loads, treat the
  /// user as a non-host so we don't briefly flash host controls to a joiner.
  ///
  /// We compare by id against the live auth user (NOT the snapshot's cached
  /// `isCurrentUser` flag). The snapshot computes that flag from
  /// `_client.auth.currentUser?.id` at fetch time; if auth.currentUser
  /// briefly returns null during anonymous-session restore, every member
  /// gets `isCurrentUser=false` and the user is permanently mis-identified
  /// as a joiner until the next snapshot. The id comparison here is
  /// stable across that timing window.
  bool get _isLocalHost {
    final myId = ref.read(supabaseServiceProvider).currentUser?.id;
    if (myId == null) return false;
    for (final m in _members) {
      if (m.id == myId) return m.isHost;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSnapshot();
      final supabase = ref.read(supabaseServiceProvider);
      _disposeMembershipSub = supabase.subscribeToRoomMembership(
        roomId: widget.roomId,
        onChanged: _loadSnapshot,
      );
    });
  }

  @override
  void dispose() {
    _disposeMembershipSub?.call();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final snap = await supabase.fetchRoomSnapshot(roomId: widget.roomId);
      if (!mounted) return;
      setState(() {
        _members = snap.members;
        _socialMode = snap.socialMode;
        _roomCode = snap.roomCode;
        _gameType = snap.gameType;
        _maxPlayers = snap.maxPlayers;
      });
      // Keep the game-side identity lookup current as members come and go
      // (humans joining, bots being added) so seat labels stay correct even
      // mid-game.
      ref.read(roomMembersProvider.notifier).state = {
        for (final m in snap.members) m.id: m,
      };

      // If the host started the game while we were on this screen, follow
      // them to the game route. The host's _startGame() also navigates
      // explicitly — _navigatedToGame guards against double-push.
      if (snap.status == 'playing' && !_navigatedToGame) {
        _navigatedToGame = true;
        // Joiners need the game type set on the provider so the game state
        // deserializer knows which subclass to construct. We deliberately
        // do NOT populate roomBotsProvider here — only the host runs bots,
        // which avoids two devices racing to send the same bot move.
        ref.read(gameTypeProvider.notifier).state = snap.gameType;
        context.replace(AppRoutes.gamePath(widget.roomId));
      }
    } catch (e) {
      debugPrint('[RoomScreen] fetchRoomSnapshot failed: $e');
    }
  }

  void _copyRoomCode() {
    final code = _roomCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code $code copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareRoomCode() async {
    final code = _roomCode;
    if (code == null) return;
    await Share.share(
      'Join my Gathr room — code: $code',
      subject: 'Join my room',
    );
  }

  /// Add a bot at the next available seat. Called from the per-seat icons
  /// on [PlayerSlotWidget] so the user picks a difficulty in one tap — no
  /// bottom sheet round-trip. Server-side, `add_bot_to_room` always fills
  /// the next available seat, so we don't need to thread a seat index.
  Future<void> _addBotWithDifficulty(String difficulty) async {
    if (_isAddingBot) return;
    setState(() => _isAddingBot = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      await supabase.addBot(
        roomId: widget.roomId,
        difficulty: difficulty,
      );
      // Realtime membership subscription flips the empty slot into the
      // new bot's slot within a tick — no snackbar needed.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add bot: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingBot = false);
    }
  }

  Future<void> _addBot() async {
    final difficulty = await GlassBottomSheet.show<String>(
      context: context,
      title: 'Select Difficulty',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in ['Easy', 'Medium', 'Hard'])
            ListTile(
              leading: Icon(
                d == 'Easy'
                    ? Icons.sentiment_satisfied
                    : d == 'Medium'
                        ? Icons.psychology
                        : Icons.local_fire_department,
                color: d == 'Easy'
                    ? AppColors.success
                    : d == 'Medium'
                        ? AppColors.accent
                        : AppColors.danger,
              ),
              title: Text(d, style: const TextStyle(color: AppColors.textDark)),
              onTap: () => Navigator.pop(context, d.toLowerCase()),
            ),
        ],
      ),
    );

    if (difficulty == null) return;
    if (_isAddingBot) return;
    setState(() => _isAddingBot = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      await supabase.addBot(
        roomId: widget.roomId,
        difficulty: difficulty,
      );
      // No success snackbar — it covers the Add Bot / Start Game buttons
      // and the realtime subscription updates the seat list within a tick
      // (an empty seat flips to the new bot, which is the natural ack).
      // The button stays disabled (spinner) until this future resolves so
      // a slow round-trip can't be double-tapped.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add bot: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingBot = false);
    }
  }

  Future<void> _startGame() async {
    setState(() => _isStarting = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);

      // Load bots BEFORE calling startGame so they're already in
      // roomBotsProvider by the time the room-status realtime event fires
      // (which can navigate via _loadSnapshot and dispose this screen
      // before our `if (mounted)` block below runs). Without this, the
      // host's roomBotsProvider stays empty and no bot ever plays.
      try {
        final roomData = await supabase.client
            .from('game_rooms')
            .select('config')
            .eq('id', widget.roomId)
            .single();
        final config = roomData['config'] as Map<String, dynamic>?;
        final botsList = (config?['bots'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        ref.read(roomBotsProvider.notifier).state = botsList
            .map((b) => BotInfo(
                  id: b['id'] as String,
                  difficulty: (b['difficulty'] as String?) ?? 'medium',
                ))
            .toList();
        print('[RoomScreen] Pre-loaded ${botsList.length} bots');
      } catch (e) {
        print('[RoomScreen] Failed to pre-load bots: $e');
      }

      // Mark navigation BEFORE the await so the realtime snapshot path
      // also sees `_navigatedToGame=true` and treats this as a host nav,
      // not a joiner nav. Either path navigates safely because the bots
      // are already in the provider.
      _navigatedToGame = true;

      final result = await supabase.startGame(roomId: widget.roomId);

      if (mounted) {
        // The edge function returns 4xx as a JSON body { error, code } with
        // no exception — detect it before treating the result as success.
        // The 'ALREADY_STARTED' code in particular surfaces when forfeit
        // didn't clean up properly (pre-2026-06-11 bug) and the room is
        // still status='playing'. With slot-substitution-on-forfeit now in
        // place this is rare, but keep the handler as a fail-loud guard.
        final errorCode = result['code'] as String?;
        if (errorCode != null) {
          _navigatedToGame = false;
          final message = switch (errorCode) {
            'ALREADY_STARTED' =>
              'This room already has a game in progress. Try rejoining from the home screen.',
            'NOT_ENOUGH_PLAYERS' =>
              'Need at least 2 players (humans + bots) to start.',
            'NOT_HOST' => 'Only the host can start the game.',
            _ => result['error'] as String? ?? 'Could not start game.',
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          return;
        }

        // Set game type and initial state before navigating
        final gameType = result['game_type'] as String?;
        final stateData = result['state'] as Map<String, dynamic>?;
        print('[RoomScreen] startGame result keys: ${result.keys.toList()}');
        print('[RoomScreen] gameType=$gameType, stateData null=${stateData == null}');

        if (gameType != null) {
          ref.read(gameTypeProvider.notifier).state = gameType;
        }
        if (stateData != null && gameType != null) {
          print('[RoomScreen] stateData keys: ${stateData.keys.toList()}');
          final gameState = deserializeGameState(gameType, stateData);
          print('[RoomScreen] deserialized: ${gameState != null ? 'OK' : 'NULL'}');
          if (gameState != null) {
            ref.read(gameStateProvider.notifier).updateState(gameState);
          }
        }

        context.push(AppRoutes.gamePath(widget.roomId));
      }
    } catch (e) {
      if (mounted) {
        _navigatedToGame = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showSettings() {
    final modes = [
      ('Full', 'full', Icons.mic),
      ('Chat Only', 'chat_only', Icons.chat_bubble_outline),
      ('Silent', 'silent', Icons.volume_off),
      ('Focus', 'focus', Icons.visibility),
    ];

    GlassBottomSheet.show(
      context: context,
      title: 'Social Mode',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, value, icon) in modes)
            ListTile(
              leading: Icon(icon, color: AppColors.textMuted),
              title:
                  Text(label, style: const TextStyle(color: AppColors.textDark)),
              trailing: _socialMode == value
                  ? Icon(Icons.check_circle, color: AppColors.accent)
                  : null,
              onTap: () {
                final supabase = ref.read(supabaseServiceProvider);
                supabase.updateRoomSocialMode(
                  roomId: widget.roomId,
                  mode: value,
                );
                setState(() => _socialMode = value);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerColors = [
      AppColors.player1,
      AppColors.player2,
      AppColors.player3,
      AppColors.player4,
    ];

    return FeltBackground(
      child: Scaffold(
        key: const Key('room-screen'),
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: 'Room',
          actions: [
            IconButton(
              key: const Key('room-settings-button'),
              icon: const Icon(Icons.settings, color: AppColors.textDark),
              onPressed: _showSettings,
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            children: [
              // Room code display + Copy/Share actions
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Room Code',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textFeltMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roomCode ?? '------',
                      key: const Key('room-code'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textOnFelt,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          key: const Key('room-code-copy'),
                          onPressed: _roomCode == null ? null : _copyRoomCode,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textOnFelt,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          key: const Key('room-code-share'),
                          onPressed: _roomCode == null ? null : _shareRoomCode,
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textOnFelt,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Player slots
              Text(
                'Players',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnFelt,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _maxPlayers,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index < _members.length) {
                      final m = _members[index];
                      final label = m.isBot
                          ? (m.botDifficulty == null
                              ? 'Bot'
                              : 'Bot · ${m.botDifficulty}')
                          : (m.isCurrentUser ? 'You' : m.displayName);
                      return PlayerSlotWidget(
                        key: const Key('player-slot'),
                        playerName: label,
                        isHost: m.isHost,
                        isBot: m.isBot,
                        isReady: m.isReady,
                        playerColor:
                            playerColors[m.seatIndex % playerColors.length],
                      );
                    }
                    // Empty seat: host gets per-difficulty add-bot icons;
                    // non-host sees the dim "waiting" placeholder. We pass
                    // _isAddingBot so the spinner shows on *every* empty
                    // slot during the RPC round-trip — the next call lands
                    // on the right seat naturally via the server's next-
                    // seat counter, so we don't need per-slot loading.
                    return PlayerSlotWidget(
                      isEmpty: true,
                      onAddBot: _isLocalHost ? _addBotWithDifficulty : null,
                      isAddingBot: _isAddingBot,
                    );
                  },
                ),
              ),

              // Action buttons: Ready + Start Game (host) / waiting hint
              // (joiner). The Add Bot button has moved into each empty
              // seat slot above, so it isn't repeated down here.
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: _isReady ? 'Not Ready' : 'Ready',
                            onPressed: () => setState(() => _isReady = !_isReady),
                            variant: GlassButtonVariant.outlined,
                            color: _isReady ? AppColors.danger : AppColors.success,
                          ),
                        ),
                        if (_isLocalHost) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: GlassButton(
                              label: 'Start Game',
                              isLoading: _isStarting,
                              onPressed: _members.length >= _minPlayersForGame
                                  ? _startGame
                                  : null,
                              size: GlassButtonSize.large,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!_isLocalHost) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for host to start the game…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textFeltMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
