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
import 'widgets/player_slot_widget.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final List<String> _players = ['You'];
  String _socialMode = 'full';
  bool _isReady = false;
  bool _isStarting = false;
  String? _roomCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supabase = ref.read(supabaseServiceProvider);
      supabase.subscribeToRoom(
        roomId: widget.roomId,
        onUpdate: (_) {},
      );
      _loadRoomCode();
    });
  }

  Future<void> _loadRoomCode() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final code = await supabase.getRoomCode(roomId: widget.roomId);
      if (mounted) setState(() => _roomCode = code);
    } catch (_) {
      // Non-critical — code container will keep showing the loading placeholder.
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
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join my Game Platform room — code: $code',
        subject: 'Join my room',
      ),
    );
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

    if (difficulty != null) {
      final supabase = ref.read(supabaseServiceProvider);
      final botId = await supabase.addBot(
        roomId: widget.roomId,
        difficulty: difficulty,
      );
      setState(() => _players.add(botId));
    }
  }

  Future<void> _startGame() async {
    setState(() => _isStarting = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final result = await supabase.startGame(roomId: widget.roomId);

      if (mounted) {
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

        // Populate bot info from room config for client-side bot moves
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
          print('[RoomScreen] Loaded ${botsList.length} bots');
        } catch (e) {
          print('[RoomScreen] Failed to load bots: $e');
        }

        context.push(AppRoutes.gamePath(widget.roomId));
      }
    } catch (e) {
      if (mounted) {
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
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index < _players.length) {
                      final player = _players[index];
                      final isBot =
                          player != 'You' && player.startsWith('bot_');
                      return PlayerSlotWidget(
                        key: const Key('player-slot'),
                        playerName: player,
                        isHost: index == 0,
                        isBot: isBot,
                        isReady: false,
                        playerColor: playerColors[index % playerColors.length],
                      );
                    }
                    return const PlayerSlotWidget(isEmpty: true);
                  },
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    GlassButton(
                      label: 'Add Bot',
                      onPressed: _addBot,
                      variant: GlassButtonVariant.outlined,
                      size: GlassButtonSize.large,
                      width: double.infinity,
                      icon: Icon(Icons.smart_toy, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassButton(
                            label: 'Start Game',
                            isLoading: _isStarting,
                            onPressed: _players.length >= 2 ? _startGame : null,
                            size: GlassButtonSize.large,
                          ),
                        ),
                      ],
                    ),
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
