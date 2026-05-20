import 'package:equatable/equatable.dart';

/// Type of chat message.
enum MessageType { text, emoji, system }

/// Channel for chat messages.
enum ChatChannel { all, team, spectator }

/// Chat message model for in-game communication.
///
/// Maps to the `chat_messages` table in the database.
class ChatMessage extends Equatable {
  final String id;
  final String roomId;
  final String userId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final MessageType type;
  final ChatChannel channel;
  final bool isSpectatorChat;
  final DateTime createdAt;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.type = MessageType.text,
    this.channel = ChatChannel.all,
    this.isSpectatorChat = false,
    required this.createdAt,
    this.isDeleted = false,
  });

  @override
  List<Object?> get props => [
        id,
        roomId,
        userId,
        content,
        type,
        channel,
        isSpectatorChat,
        createdAt,
        isDeleted,
      ];

  ChatMessage copyWith({
    bool? isDeleted,
    String? content,
  }) {
    return ChatMessage(
      id: id,
      roomId: roomId,
      userId: userId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      content: content ?? this.content,
      type: type,
      channel: channel,
      isSpectatorChat: isSpectatorChat,
      createdAt: createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'user_id': userId,
        'content': content,
        'is_spectator_chat': isSpectatorChat,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    required String senderName,
    String? senderAvatarUrl,
  }) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      content: json['content'] as String,
      isSpectatorChat: json['is_spectator_chat'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
