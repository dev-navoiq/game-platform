# 11 - Social Features

> Implement chat, voice communication, and democratic moderation system.

## Task

Build comprehensive social features including:
- Real-time text chat with team/all channels
- Quick emoji reactions
- Voice chat with LiveKit integration
- Democratic mute voting (50% threshold)
- Friend system
- Player blocking

---

## Architecture

```
packages/social_core/
├── lib/
│   ├── social_core.dart
│   └── src/
│       ├── chat/
│       │   ├── chat_message.dart
│       │   ├── chat_repository.dart
│       │   └── chat_service.dart
│       ├── voice/
│       │   ├── voice_service.dart
│       │   ├── voice_state.dart
│       │   └── livekit_client.dart
│       ├── moderation/
│       │   ├── mute_vote.dart
│       │   ├── moderation_service.dart
│       │   └── report_service.dart
│       ├── friends/
│       │   ├── friendship.dart
│       │   └── friends_repository.dart
│       └── reactions/
│           ├── reaction.dart
│           └── reaction_service.dart
```

---

## Chat System

### Chat Message Model

```dart
// packages/social_core/lib/src/chat/chat_message.dart

import 'package:equatable/equatable.dart';

enum MessageType { text, emoji, system, reaction }
enum ChatChannel { all, team }

class ChatMessage extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final MessageType type;
  final ChatChannel channel;
  final DateTime createdAt;
  final bool isDeleted;
  final String? replyToId;
  final Map<String, int> reactions; // emoji -> count

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.type = MessageType.text,
    this.channel = ChatChannel.all,
    required this.createdAt,
    this.isDeleted = false,
    this.replyToId,
    this.reactions = const {},
  });

  @override
  List<Object?> get props => [
    id, roomId, senderId, content, type, channel, createdAt, isDeleted
  ];

  ChatMessage copyWith({
    bool? isDeleted,
    Map<String, int>? reactions,
  }) {
    return ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      content: content,
      type: type,
      channel: channel,
      createdAt: createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId,
      reactions: reactions ?? this.reactions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_id': roomId,
    'sender_id': senderId,
    'content': content,
    'type': type.name,
    'channel': channel.name,
    'created_at': createdAt.toIso8601String(),
    'is_deleted': isDeleted,
    'reply_to_id': replyToId,
    'reactions': reactions,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json, {
    required String senderName,
    String? senderAvatarUrl,
  }) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      content: json['content'] as String,
      type: MessageType.values.byName(json['type'] as String? ?? 'text'),
      channel: ChatChannel.values.byName(json['channel'] as String? ?? 'all'),
      createdAt: DateTime.parse(json['created_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      replyToId: json['reply_to_id'] as String?,
      reactions: Map<String, int>.from(json['reactions'] as Map? ?? {}),
    );
  }
}
```

### Chat Service

```dart
// packages/social_core/lib/src/chat/chat_service.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_message.dart';

class ChatService {
  final SupabaseClient _supabase;
  final String _roomId;
  final String _currentUserId;
  final int? _currentTeam;

  RealtimeChannel? _channel;
  final _messagesController = StreamController<ChatMessage>.broadcast();
  final List<ChatMessage> _messages = [];

  // Rate limiting
  DateTime? _lastMessageTime;
  static const _messageCooldown = Duration(seconds: 2);
  static const _maxMessageLength = 500;

  ChatService({
    required SupabaseClient supabase,
    required String roomId,
    required String currentUserId,
    int? currentTeam,
  })  : _supabase = supabase,
        _roomId = roomId,
        _currentUserId = currentUserId,
        _currentTeam = currentTeam;

  Stream<ChatMessage> get messageStream => _messagesController.stream;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Future<void> connect() async {
    // Load recent messages
    final response = await _supabase
        .from('chat_messages')
        .select('*, profiles!sender_id(username, avatar_url)')
        .eq('room_id', _roomId)
        .order('created_at', ascending: false)
        .limit(100);

    for (final row in response.reversed) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final message = ChatMessage.fromJson(
        row,
        senderName: profile?['username'] as String? ?? 'Unknown',
        senderAvatarUrl: profile?['avatar_url'] as String?,
      );
      _messages.add(message);
      _messagesController.add(message);
    }

    // Subscribe to new messages
    _channel = _supabase.channel('room:$_roomId:chat')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: _roomId,
        ),
        callback: (payload) => _handleNewMessage(payload.newRecord),
      )
      ..subscribe();
  }

  void _handleNewMessage(Map<String, dynamic> data) async {
    // Fetch sender profile
    final profile = await _supabase
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', data['sender_id'])
        .single();

    final message = ChatMessage.fromJson(
      data,
      senderName: profile['username'] as String,
      senderAvatarUrl: profile['avatar_url'] as String?,
    );

    // Filter team messages
    if (message.channel == ChatChannel.team &&
        _currentTeam != null &&
        _getTeamForPlayer(message.senderId) != _currentTeam) {
      return; // Skip team messages from other team
    }

    _messages.add(message);
    _messagesController.add(message);
  }

  int? _getTeamForPlayer(String playerId) {
    // Implementation depends on game state access
    return null;
  }

  Future<bool> sendMessage(
    String content, {
    ChatChannel channel = ChatChannel.all,
    String? replyToId,
  }) async {
    // Validate
    if (content.isEmpty || content.length > _maxMessageLength) {
      return false;
    }

    // Rate limit
    if (_lastMessageTime != null) {
      final elapsed = DateTime.now().difference(_lastMessageTime!);
      if (elapsed < _messageCooldown) {
        return false;
      }
    }

    try {
      await _supabase.from('chat_messages').insert({
        'room_id': _roomId,
        'sender_id': _currentUserId,
        'content': content.trim(),
        'type': 'text',
        'channel': channel.name,
        'reply_to_id': replyToId,
      });

      _lastMessageTime = DateTime.now();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendReaction(String emoji, {String? targetMessageId}) async {
    try {
      await _supabase.from('quick_reactions').insert({
        'room_id': _roomId,
        'player_id': _currentUserId,
        'reaction_type': 'emoji',
        'reaction_value': emoji,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await _channel?.unsubscribe();
    await _messagesController.close();
  }
}
```

---

## Quick Reactions

### Reaction Widget

```dart
// lib/shared/widgets/chat/quick_reactions.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickReactions extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const QuickReactions({
    super.key,
    required this.onReactionSelected,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  State<QuickReactions> createState() => _QuickReactionsState();
}

class _QuickReactionsState extends State<QuickReactions>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const List<String> _reactions = ['👍', '😂', '😮', '🔥', '💔', '🎉', '👏', '🤔'];
  static const List<String> _phrases = ['Nice!', 'GG', 'Oops', 'My bad', 'Good luck'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    if (widget.isExpanded) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(QuickReactions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onToggle?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              widget.isExpanded ? Icons.close : Icons.emoji_emotions,
              color: Colors.white,
            ),
          ),
        ),

        // Reactions panel
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOut,
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emojis
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reactions.map((emoji) {
                    return _ReactionButton(
                      content: emoji,
                      isEmoji: true,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onReactionSelected(emoji);
                        widget.onToggle?.call();
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),

                // Quick phrases
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _phrases.map((phrase) {
                    return _ReactionButton(
                      content: phrase,
                      isEmoji: false,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onReactionSelected(phrase);
                        widget.onToggle?.call();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String content;
  final bool isEmoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.content,
    required this.isEmoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isEmoji ? 10 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_isPressed ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            widget.content,
            style: TextStyle(
              fontSize: widget.isEmoji ? 24 : 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Voice Chat Service

```dart
// packages/social_core/lib/src/voice/voice_service.dart

import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import 'voice_state.dart';

enum VoiceStatus { disconnected, connecting, connected, muted, deafened }

class VoiceService {
  Room? _room;
  LocalParticipant? _localParticipant;

  final _statusController = StreamController<VoiceStatus>.broadcast();
  final _participantsController = StreamController<List<VoiceParticipant>>.broadcast();
  final _speakingController = StreamController<Map<String, bool>>.broadcast();

  Stream<VoiceStatus> get statusStream => _statusController.stream;
  Stream<List<VoiceParticipant>> get participantsStream => _participantsController.stream;
  Stream<Map<String, bool>> get speakingStream => _speakingController.stream;

  VoiceStatus _currentStatus = VoiceStatus.disconnected;
  VoiceStatus get currentStatus => _currentStatus;

  final Map<String, bool> _speakingStates = {};

  Future<bool> connect({
    required String serverUrl,
    required String token,
    required String roomName,
  }) async {
    try {
      _updateStatus(VoiceStatus.connecting);

      _room = Room();

      _room!.addListener(_RoomListener(
        onParticipantConnected: _handleParticipantConnected,
        onParticipantDisconnected: _handleParticipantDisconnected,
        onActiveSpeakersChanged: _handleActiveSpeakersChanged,
      ));

      await _room!.connect(
        serverUrl,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            audioBitrate: AudioPreset.speech.maxBitrate,
          ),
        ),
      );

      _localParticipant = _room!.localParticipant;

      // Enable microphone
      await _localParticipant!.setMicrophoneEnabled(true);

      _updateStatus(VoiceStatus.connected);
      _updateParticipants();

      return true;
    } catch (e) {
      _updateStatus(VoiceStatus.disconnected);
      return false;
    }
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
    _localParticipant = null;
    _updateStatus(VoiceStatus.disconnected);
    _speakingStates.clear();
  }

  Future<void> toggleMute() async {
    if (_localParticipant == null) return;

    final isMuted = _localParticipant!.isMicrophoneEnabled();
    await _localParticipant!.setMicrophoneEnabled(!isMuted);

    _updateStatus(isMuted ? VoiceStatus.connected : VoiceStatus.muted);
  }

  Future<void> setMuted(bool muted) async {
    if (_localParticipant == null) return;

    await _localParticipant!.setMicrophoneEnabled(!muted);
    _updateStatus(muted ? VoiceStatus.muted : VoiceStatus.connected);
  }

  void _updateStatus(VoiceStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void _handleParticipantConnected(RemoteParticipant participant) {
    _updateParticipants();
  }

  void _handleParticipantDisconnected(RemoteParticipant participant) {
    _updateParticipants();
  }

  void _handleActiveSpeakersChanged(List<Participant> speakers) {
    _speakingStates.clear();
    for (final speaker in speakers) {
      _speakingStates[speaker.identity] = true;
    }
    _speakingController.add(Map.from(_speakingStates));
  }

  void _updateParticipants() {
    if (_room == null) return;

    final participants = <VoiceParticipant>[];

    // Add local participant
    if (_localParticipant != null) {
      participants.add(VoiceParticipant(
        id: _localParticipant!.identity,
        name: _localParticipant!.name ?? 'You',
        isMuted: !_localParticipant!.isMicrophoneEnabled(),
        isSpeaking: _speakingStates[_localParticipant!.identity] ?? false,
        isLocal: true,
      ));
    }

    // Add remote participants
    for (final participant in _room!.remoteParticipants.values) {
      participants.add(VoiceParticipant(
        id: participant.identity,
        name: participant.name ?? participant.identity,
        isMuted: !participant.isMicrophoneEnabled(),
        isSpeaking: _speakingStates[participant.identity] ?? false,
        isLocal: false,
      ));
    }

    _participantsController.add(participants);
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _participantsController.close();
    await _speakingController.close();
  }
}

class _RoomListener extends RoomListener {
  final void Function(RemoteParticipant)? onParticipantConnected;
  final void Function(RemoteParticipant)? onParticipantDisconnected;
  final void Function(List<Participant>)? onActiveSpeakersChanged;

  _RoomListener({
    this.onParticipantConnected,
    this.onParticipantDisconnected,
    this.onActiveSpeakersChanged,
  });

  @override
  void onParticipantConnected(RemoteParticipant participant) {
    onParticipantConnected?.call(participant);
  }

  @override
  void onParticipantDisconnected(RemoteParticipant participant) {
    onParticipantDisconnected?.call(participant);
  }

  @override
  void onActiveSpeakersChanged(List<Participant> speakers) {
    onActiveSpeakersChanged?.call(speakers);
  }
}

class VoiceParticipant {
  final String id;
  final String name;
  final bool isMuted;
  final bool isSpeaking;
  final bool isLocal;
  final bool isMutedByVote;

  const VoiceParticipant({
    required this.id,
    required this.name,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isLocal = false,
    this.isMutedByVote = false,
  });
}
```

---

## Democratic Mute System

```dart
// packages/social_core/lib/src/moderation/moderation_service.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MuteVoteStatus { pending, passed, failed, expired }

class MuteVote {
  final String id;
  final String roomId;
  final String targetPlayerId;
  final String targetPlayerName;
  final String initiatorId;
  final int yesVotes;
  final int noVotes;
  final int totalVoters;
  final DateTime expiresAt;
  final MuteVoteStatus status;

  MuteVote({
    required this.id,
    required this.roomId,
    required this.targetPlayerId,
    required this.targetPlayerName,
    required this.initiatorId,
    required this.yesVotes,
    required this.noVotes,
    required this.totalVoters,
    required this.expiresAt,
    required this.status,
  });

  double get yesPercentage =>
      totalVoters > 0 ? yesVotes / totalVoters : 0;

  bool get isPassed => yesPercentage >= 0.5;

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class ModerationService {
  final SupabaseClient _supabase;
  final String _roomId;
  final String _currentUserId;

  RealtimeChannel? _channel;
  final _voteController = StreamController<MuteVote>.broadcast();
  final _muteListController = StreamController<List<String>>.broadcast();

  final Map<String, MuteVote> _activeVotes = {};
  final Set<String> _mutedPlayers = {};

  // Cooldowns
  final Map<String, DateTime> _voteCooldowns = {};
  static const _voteCooldown = Duration(minutes: 5);
  static const _voteExpiry = Duration(seconds: 30);

  ModerationService({
    required SupabaseClient supabase,
    required String roomId,
    required String currentUserId,
  })  : _supabase = supabase,
        _roomId = roomId,
        _currentUserId = currentUserId;

  Stream<MuteVote> get voteStream => _voteController.stream;
  Stream<List<String>> get mutedPlayersStream => _muteListController.stream;
  List<String> get mutedPlayers => List.unmodifiable(_mutedPlayers);

  bool isPlayerMuted(String playerId) => _mutedPlayers.contains(playerId);

  Future<void> connect() async {
    // Load existing mutes
    final mutedResponse = await _supabase
        .from('room_players')
        .select('user_id')
        .eq('room_id', _roomId)
        .eq('is_voice_muted_by_vote', true);

    for (final row in mutedResponse) {
      _mutedPlayers.add(row['user_id'] as String);
    }
    _muteListController.add(List.from(_mutedPlayers));

    // Subscribe to vote changes
    _channel = _supabase.channel('room:$_roomId:moderation')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'mute_votes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: _roomId,
        ),
        callback: (payload) => _handleVoteChange(payload),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'room_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: _roomId,
        ),
        callback: (payload) => _handleMuteStatusChange(payload),
      )
      ..subscribe();
  }

  void _handleVoteChange(PostgresChangePayload payload) async {
    // Recalculate vote status
    final targetPlayerId = payload.newRecord['target_player_id'] as String;
    await _refreshVoteStatus(targetPlayerId);
  }

  void _handleMuteStatusChange(PostgresChangePayload payload) {
    final userId = payload.newRecord['user_id'] as String?;
    final isMuted = payload.newRecord['is_voice_muted_by_vote'] as bool? ?? false;

    if (userId == null) return;

    if (isMuted) {
      _mutedPlayers.add(userId);
    } else {
      _mutedPlayers.remove(userId);
    }
    _muteListController.add(List.from(_mutedPlayers));
  }

  Future<MuteVote?> _refreshVoteStatus(String targetPlayerId) async {
    final votesResponse = await _supabase
        .from('mute_votes')
        .select('*, profiles!target_player_id(username)')
        .eq('room_id', _roomId)
        .eq('target_player_id', targetPlayerId)
        .gt('expires_at', DateTime.now().toIso8601String());

    if (votesResponse.isEmpty) {
      _activeVotes.remove(targetPlayerId);
      return null;
    }

    final totalVoters = await _getTotalVoters();
    int yesVotes = 0;
    int noVotes = 0;
    String? initiatorId;
    DateTime? expiresAt;
    String targetName = 'Unknown';

    for (final row in votesResponse) {
      if (row['vote'] == true) {
        yesVotes++;
      } else {
        noVotes++;
      }
      initiatorId ??= row['voter_id'] as String;
      expiresAt ??= DateTime.parse(row['expires_at'] as String);

      final profile = row['profiles'] as Map<String, dynamic>?;
      targetName = profile?['username'] as String? ?? 'Unknown';
    }

    final vote = MuteVote(
      id: targetPlayerId,
      roomId: _roomId,
      targetPlayerId: targetPlayerId,
      targetPlayerName: targetName,
      initiatorId: initiatorId!,
      yesVotes: yesVotes,
      noVotes: noVotes,
      totalVoters: totalVoters,
      expiresAt: expiresAt!,
      status: MuteVoteStatus.pending,
    );

    _activeVotes[targetPlayerId] = vote;
    _voteController.add(vote);

    return vote;
  }

  Future<int> _getTotalVoters() async {
    final response = await _supabase
        .from('room_players')
        .select('user_id')
        .eq('room_id', _roomId)
        .eq('is_bot', false);

    // Exclude the target from voters
    return response.length - 1;
  }

  /// Initiate a mute vote against a player
  Future<MuteVoteResult> initiateMuteVote(String targetPlayerId) async {
    // Can't vote on self
    if (targetPlayerId == _currentUserId) {
      return MuteVoteResult.cannotVoteSelf;
    }

    // Check cooldown
    final lastVote = _voteCooldowns[targetPlayerId];
    if (lastVote != null && DateTime.now().difference(lastVote) < _voteCooldown) {
      return MuteVoteResult.onCooldown;
    }

    // Check if already muted
    if (_mutedPlayers.contains(targetPlayerId)) {
      return MuteVoteResult.alreadyMuted;
    }

    // Check if vote already active
    if (_activeVotes.containsKey(targetPlayerId)) {
      return MuteVoteResult.voteAlreadyActive;
    }

    try {
      // Create vote (automatically votes yes)
      await _supabase.from('mute_votes').insert({
        'room_id': _roomId,
        'target_player_id': targetPlayerId,
        'voter_id': _currentUserId,
        'vote': true,
        'expires_at': DateTime.now().add(_voteExpiry).toIso8601String(),
      });

      _voteCooldowns[targetPlayerId] = DateTime.now();

      return MuteVoteResult.success;
    } catch (e) {
      return MuteVoteResult.error;
    }
  }

  /// Cast a vote in an active mute vote
  Future<bool> castVote(String targetPlayerId, bool voteMute) async {
    if (targetPlayerId == _currentUserId) return false;

    try {
      await _supabase.from('mute_votes').upsert({
        'room_id': _roomId,
        'target_player_id': targetPlayerId,
        'voter_id': _currentUserId,
        'vote': voteMute,
        'expires_at': DateTime.now().add(_voteExpiry).toIso8601String(),
      }, onConflict: 'room_id,target_player_id,voter_id');

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await _channel?.unsubscribe();
    await _voteController.close();
    await _muteListController.close();
  }
}

enum MuteVoteResult {
  success,
  cannotVoteSelf,
  onCooldown,
  alreadyMuted,
  voteAlreadyActive,
  error,
}
```

---

## Mute Vote UI

```dart
// lib/shared/widgets/moderation/mute_vote_overlay.dart

import 'package:flutter/material.dart';
import 'dart:async';

class MuteVoteOverlay extends StatefulWidget {
  final String targetPlayerName;
  final int yesVotes;
  final int noVotes;
  final int totalVoters;
  final Duration timeRemaining;
  final bool hasVoted;
  final Function(bool) onVote;
  final VoidCallback? onDismiss;

  const MuteVoteOverlay({
    super.key,
    required this.targetPlayerName,
    required this.yesVotes,
    required this.noVotes,
    required this.totalVoters,
    required this.timeRemaining,
    required this.hasVoted,
    required this.onVote,
    this.onDismiss,
  });

  @override
  State<MuteVoteOverlay> createState() => _MuteVoteOverlayState();
}

class _MuteVoteOverlayState extends State<MuteVoteOverlay> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeRemaining;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.isNegative) {
          _timer.cancel();
          widget.onDismiss?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final votesNeeded = (widget.totalVoters * 0.5).ceil();
    final yesPercentage = widget.totalVoters > 0
        ? widget.yesVotes / widget.totalVoters
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.how_to_vote, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mute Vote: ${widget.targetPlayerName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_remaining.inSeconds}s',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: yesPercentage,
              minHeight: 8,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(
                yesPercentage >= 0.5 ? Colors.orange : Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Vote count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yes: ${widget.yesVotes}',
                style: const TextStyle(color: Colors.orange),
              ),
              Text(
                'Need: $votesNeeded votes',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              Text(
                'No: ${widget.noVotes}',
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Vote buttons
          if (!widget.hasVoted)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onVote(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mute'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onVote(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    child: const Text('Keep'),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Vote recorded',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
```

---

## Friend System

```dart
// packages/social_core/lib/src/friends/friends_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class Friendship {
  final String id;
  final String friendId;
  final String friendName;
  final String? friendAvatarUrl;
  final bool isAccepted;
  final bool isPending;
  final bool isOnline;
  final DateTime? lastOnline;

  Friendship({
    required this.id,
    required this.friendId,
    required this.friendName,
    this.friendAvatarUrl,
    required this.isAccepted,
    required this.isPending,
    this.isOnline = false,
    this.lastOnline,
  });
}

class FriendsRepository {
  final SupabaseClient _supabase;
  final String _currentUserId;

  FriendsRepository({
    required SupabaseClient supabase,
    required String currentUserId,
  })  : _supabase = supabase,
        _currentUserId = currentUserId;

  Future<List<Friendship>> getFriends() async {
    final response = await _supabase
        .from('friendships')
        .select('*, profiles!friend_id(username, avatar_url, last_online_at)')
        .eq('user_id', _currentUserId)
        .eq('is_accepted', true);

    return response.map((row) {
      final profile = row['profiles'] as Map<String, dynamic>;
      return Friendship(
        id: row['id'] as String,
        friendId: row['friend_id'] as String,
        friendName: profile['username'] as String,
        friendAvatarUrl: profile['avatar_url'] as String?,
        isAccepted: true,
        isPending: false,
        lastOnline: profile['last_online_at'] != null
            ? DateTime.parse(profile['last_online_at'] as String)
            : null,
      );
    }).toList();
  }

  Future<List<Friendship>> getPendingRequests() async {
    final response = await _supabase
        .from('friendships')
        .select('*, profiles!user_id(username, avatar_url)')
        .eq('friend_id', _currentUserId)
        .eq('is_accepted', false);

    return response.map((row) {
      final profile = row['profiles'] as Map<String, dynamic>;
      return Friendship(
        id: row['id'] as String,
        friendId: row['user_id'] as String,
        friendName: profile['username'] as String,
        friendAvatarUrl: profile['avatar_url'] as String?,
        isAccepted: false,
        isPending: true,
      );
    }).toList();
  }

  Future<bool> sendFriendRequest(String friendId) async {
    try {
      await _supabase.from('friendships').insert({
        'user_id': _currentUserId,
        'friend_id': friendId,
        'is_accepted': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .update({
            'is_accepted': true,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeFriend(String friendshipId) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': _currentUserId,
        'blocked_id': userId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', _currentUserId)
          .eq('blocked_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getBlockedUsers() async {
    final response = await _supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', _currentUserId);

    return response.map((r) => r['blocked_id'] as String).toList();
  }
}
```

---

## Expected Output

- Complete chat system with real-time messaging
- Quick reactions with emoji bubbles
- Voice chat integration with LiveKit
- Democratic mute voting (50% threshold)
- Friend system with requests
- User blocking functionality
- Moderation logging
- Rate limiting and spam prevention
