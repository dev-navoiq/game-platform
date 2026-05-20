import 'package:game_core/game_core.dart';

/// Centralized social mode enforcement and message validation.
///
/// All UI widgets and services should delegate to these methods
/// rather than implementing their own social mode checks.
class ChatRules {
  ChatRules._();

  static const int maxMessageLength = 500;
  static const int minMessageLength = 1;

  /// Validate a chat message.
  ///
  /// Returns `null` if the message is valid, or an error description string.
  static String? validateMessage(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return 'Message cannot be empty';
    }
    if (trimmed.length > maxMessageLength) {
      return 'Message exceeds $maxMessageLength characters';
    }
    return null;
  }

  /// Whether text chat is allowed in the given social mode.
  ///
  /// Allowed in: Full, Chat Only.
  /// Blocked in: Silent, Focus.
  static bool isChatAllowed(RoomSocialMode mode) {
    return mode == RoomSocialMode.full || mode == RoomSocialMode.chatOnly;
  }

  /// Whether emoji reactions are allowed in the given social mode.
  ///
  /// Allowed in: Full, Chat Only, Focus (limited set).
  /// Blocked in: Silent.
  static bool areReactionsAllowed(RoomSocialMode mode) {
    return mode != RoomSocialMode.silent;
  }

  /// Whether voice chat is allowed in the given social mode.
  ///
  /// Allowed in: Full only.
  static bool isVoiceAllowed(RoomSocialMode mode) {
    return mode == RoomSocialMode.full;
  }

  /// Whether floating chat bubbles should display.
  ///
  /// Allowed in: Full, Chat Only.
  /// Blocked in: Silent, Focus.
  static bool areBubblesAllowed(RoomSocialMode mode) {
    return mode == RoomSocialMode.full || mode == RoomSocialMode.chatOnly;
  }
}
