import 'package:equatable/equatable.dart';

/// Kind of direct message. `text` is a free-form chat line. `gameInvite`
/// carries a room reference in [DirectMessage.payload] so the recipient
/// can join with one tap. `tournamentInvite` carries a tournament
/// reference; `partyInvite` a party reference (M3). `system` is reserved
/// for server-emitted lines (e.g. "Friend declined invite").
enum DirectMessageType { text, gameInvite, tournamentInvite, partyInvite, system }

extension DirectMessageTypeWire on DirectMessageType {
  String get wireValue => switch (this) {
        DirectMessageType.text => 'text',
        DirectMessageType.gameInvite => 'game_invite',
        DirectMessageType.tournamentInvite => 'tournament_invite',
        DirectMessageType.partyInvite => 'party_invite',
        DirectMessageType.system => 'system',
      };

  static DirectMessageType parse(String? raw) => switch (raw) {
        'text' => DirectMessageType.text,
        'game_invite' => DirectMessageType.gameInvite,
        'tournament_invite' => DirectMessageType.tournamentInvite,
        'party_invite' => DirectMessageType.partyInvite,
        'system' => DirectMessageType.system,
        _ => DirectMessageType.text,
      };
}

/// 1:1 message between two users. Maps to `direct_messages`.
///
/// Friend-only by RLS; see migration 20260613.
class DirectMessage extends Equatable {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final DirectMessageType type;

  /// Free-form structured data for typed messages. For `gameInvite` we
  /// store `{room_id, game_type, room_code, expires_at}`.
  final Map<String, dynamic>? payload;

  final DateTime createdAt;
  final DateTime? readAt;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.type = DirectMessageType.text,
    this.payload,
    required this.createdAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  /// True only for `gameInvite` messages that still have a usable `room_id`
  /// in their payload. Callers should additionally check expires_at.
  bool get isGameInvite =>
      type == DirectMessageType.gameInvite &&
      (payload?['room_id'] as String?) != null;

  /// True only for `tournamentInvite` messages with a usable tournament id.
  bool get isTournamentInvite =>
      type == DirectMessageType.tournamentInvite &&
      (payload?['tournament_id'] as String?) != null;

  @override
  List<Object?> get props => [
        id,
        senderId,
        recipientId,
        content,
        type,
        payload,
        createdAt,
        readAt,
      ];

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payload'];
    return DirectMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      content: json['content'] as String,
      type: DirectMessageTypeWire.parse(json['message_type'] as String?),
      payload: payloadRaw is Map<String, dynamic>
          ? payloadRaw
          : payloadRaw is Map
              ? Map<String, dynamic>.from(payloadRaw)
              : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );
  }
}

/// Roll-up of a conversation with one other user. Built client-side from
/// the raw stream of DMs because Supabase doesn't ship a server-side
/// "conversations" view.
class DirectMessageThread extends Equatable {
  /// The OTHER user's ID (never the current user's).
  final String otherUserId;

  /// Most recent message in either direction. Used for preview + sort.
  final DirectMessage lastMessage;

  /// Count of messages from `otherUserId` that the current user hasn't
  /// marked read yet.
  final int unreadCount;

  const DirectMessageThread({
    required this.otherUserId,
    required this.lastMessage,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [otherUserId, lastMessage, unreadCount];
}
