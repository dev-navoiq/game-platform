import 'package:test/test.dart';
import 'package:game_core/game_core.dart';
import 'package:social_core/social_core.dart';

void main() {
  group('ChatRules.validateMessage', () {
    test('returns null for valid message', () {
      expect(ChatRules.validateMessage('Hello!'), isNull);
    });

    test('returns null for message at max length', () {
      final msg = 'a' * 500;
      expect(ChatRules.validateMessage(msg), isNull);
    });

    test('returns error for empty string', () {
      expect(ChatRules.validateMessage(''), isNotNull);
    });

    test('returns error for whitespace-only string', () {
      expect(ChatRules.validateMessage('   '), isNotNull);
    });

    test('returns error for message exceeding max length', () {
      final msg = 'a' * 501;
      expect(ChatRules.validateMessage(msg), isNotNull);
    });

    test('trims whitespace before checking emptiness', () {
      expect(ChatRules.validateMessage('  \n\t  '), isNotNull);
    });
  });

  group('ChatRules.isChatAllowed', () {
    test('returns true for full mode', () {
      expect(ChatRules.isChatAllowed(RoomSocialMode.full), isTrue);
    });

    test('returns true for chatOnly mode', () {
      expect(ChatRules.isChatAllowed(RoomSocialMode.chatOnly), isTrue);
    });

    test('returns false for silent mode', () {
      expect(ChatRules.isChatAllowed(RoomSocialMode.silent), isFalse);
    });

    test('returns false for focus mode', () {
      expect(ChatRules.isChatAllowed(RoomSocialMode.focus), isFalse);
    });
  });

  group('ChatRules.areReactionsAllowed', () {
    test('returns true for full mode', () {
      expect(ChatRules.areReactionsAllowed(RoomSocialMode.full), isTrue);
    });

    test('returns true for chatOnly mode', () {
      expect(ChatRules.areReactionsAllowed(RoomSocialMode.chatOnly), isTrue);
    });

    test('returns false for silent mode', () {
      expect(ChatRules.areReactionsAllowed(RoomSocialMode.silent), isFalse);
    });

    test('returns true for focus mode (limited emojis)', () {
      expect(ChatRules.areReactionsAllowed(RoomSocialMode.focus), isTrue);
    });
  });

  group('ChatRules.isVoiceAllowed', () {
    test('returns true for full mode only', () {
      expect(ChatRules.isVoiceAllowed(RoomSocialMode.full), isTrue);
    });

    test('returns false for chatOnly', () {
      expect(ChatRules.isVoiceAllowed(RoomSocialMode.chatOnly), isFalse);
    });

    test('returns false for silent', () {
      expect(ChatRules.isVoiceAllowed(RoomSocialMode.silent), isFalse);
    });

    test('returns false for focus', () {
      expect(ChatRules.isVoiceAllowed(RoomSocialMode.focus), isFalse);
    });
  });

  group('ChatRules.areBubblesAllowed', () {
    test('returns true for full mode', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.full), isTrue);
    });

    test('returns true for chatOnly mode', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.chatOnly), isTrue);
    });

    test('returns false for silent mode', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.silent), isFalse);
    });

    test('returns false for focus mode', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.focus), isFalse);
    });
  });
}
