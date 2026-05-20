import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:social_core/social_core.dart';

void main() {
  group('ChatRules social mode enforcement', () {
    group('Full mode', () {
      const mode = RoomSocialMode.full;

      test('allows chat', () {
        expect(ChatRules.isChatAllowed(mode), isTrue);
      });

      test('allows reactions', () {
        expect(ChatRules.areReactionsAllowed(mode), isTrue);
      });

      test('allows voice', () {
        expect(ChatRules.isVoiceAllowed(mode), isTrue);
      });

      test('allows bubbles', () {
        expect(ChatRules.areBubblesAllowed(mode), isTrue);
      });
    });

    group('Chat Only mode', () {
      const mode = RoomSocialMode.chatOnly;

      test('allows chat', () {
        expect(ChatRules.isChatAllowed(mode), isTrue);
      });

      test('allows reactions', () {
        expect(ChatRules.areReactionsAllowed(mode), isTrue);
      });

      test('blocks voice', () {
        expect(ChatRules.isVoiceAllowed(mode), isFalse);
      });

      test('allows bubbles', () {
        expect(ChatRules.areBubblesAllowed(mode), isTrue);
      });
    });

    group('Silent mode', () {
      const mode = RoomSocialMode.silent;

      test('blocks chat', () {
        expect(ChatRules.isChatAllowed(mode), isFalse);
      });

      test('blocks reactions', () {
        expect(ChatRules.areReactionsAllowed(mode), isFalse);
      });

      test('blocks voice', () {
        expect(ChatRules.isVoiceAllowed(mode), isFalse);
      });

      test('blocks bubbles', () {
        expect(ChatRules.areBubblesAllowed(mode), isFalse);
      });
    });

    group('Focus mode', () {
      const mode = RoomSocialMode.focus;

      test('blocks chat', () {
        expect(ChatRules.isChatAllowed(mode), isFalse);
      });

      test('allows reactions', () {
        expect(ChatRules.areReactionsAllowed(mode), isTrue);
      });

      test('blocks voice', () {
        expect(ChatRules.isVoiceAllowed(mode), isFalse);
      });

      test('blocks bubbles', () {
        expect(ChatRules.areBubblesAllowed(mode), isFalse);
      });
    });
  });

  group('ChatRules message validation', () {
    test('returns null for valid message', () {
      expect(ChatRules.validateMessage('Hello!'), isNull);
    });

    test('rejects empty string', () {
      expect(ChatRules.validateMessage(''), isNotNull);
      expect(ChatRules.validateMessage(''), contains('empty'));
    });

    test('rejects whitespace-only string', () {
      expect(ChatRules.validateMessage('   '), isNotNull);
    });

    test('rejects message exceeding max length', () {
      final longMessage = 'a' * (ChatRules.maxMessageLength + 1);
      expect(ChatRules.validateMessage(longMessage), isNotNull);
      expect(
        ChatRules.validateMessage(longMessage),
        contains('${ChatRules.maxMessageLength}'),
      );
    });

    test('accepts message at exactly max length', () {
      final exactMessage = 'a' * ChatRules.maxMessageLength;
      expect(ChatRules.validateMessage(exactMessage), isNull);
    });

    test('accepts single character message', () {
      expect(ChatRules.validateMessage('x'), isNull);
    });

    test('maxMessageLength is 500', () {
      expect(ChatRules.maxMessageLength, 500);
    });

    test('minMessageLength is 1', () {
      expect(ChatRules.minMessageLength, 1);
    });
  });

  group('Integration: silent room suppresses chat and voice', () {
    const mode = RoomSocialMode.silent;

    test('silent room blocks all social features except nothing', () {
      expect(ChatRules.isChatAllowed(mode), isFalse,
          reason: 'Silent room must suppress text chat');
      expect(ChatRules.isVoiceAllowed(mode), isFalse,
          reason: 'Silent room must suppress voice chat');
      expect(ChatRules.areBubblesAllowed(mode), isFalse,
          reason: 'Silent room must suppress floating bubbles');
      expect(ChatRules.areReactionsAllowed(mode), isFalse,
          reason: 'Silent room must suppress reactions');
    });

    test('valid messages are still rejected by mode check', () {
      // Message itself is valid...
      expect(ChatRules.validateMessage('Good game!'), isNull);
      // ...but the mode blocks sending it
      expect(ChatRules.isChatAllowed(mode), isFalse);
    });
  });

  group('Integration: floating bubbles in Full/ChatOnly vs Focus', () {
    test('bubbles appear in Full mode rooms', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.full), isTrue);
      expect(ChatRules.isChatAllowed(RoomSocialMode.full), isTrue,
          reason: 'Chat must be on for bubble content to exist');
    });

    test('bubbles appear in Chat Only rooms', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.chatOnly), isTrue);
      expect(ChatRules.isChatAllowed(RoomSocialMode.chatOnly), isTrue,
          reason: 'Chat must be on for bubble content to exist');
    });

    test('bubbles are absent in Focus mode', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.focus), isFalse,
          reason: 'Focus mode blocks bubbles to reduce distractions');
      // But reactions still work in Focus mode
      expect(ChatRules.areReactionsAllowed(RoomSocialMode.focus), isTrue,
          reason: 'Focus mode allows limited reactions');
    });

    test('bubbles are absent in Silent mode', () {
      expect(ChatRules.areBubblesAllowed(RoomSocialMode.silent), isFalse);
    });
  });

  group('All modes matrix', () {
    // Exhaustive truth table for all 4 modes x 4 features
    final expected = {
      RoomSocialMode.full: {
        'chat': true,
        'reactions': true,
        'voice': true,
        'bubbles': true,
      },
      RoomSocialMode.chatOnly: {
        'chat': true,
        'reactions': true,
        'voice': false,
        'bubbles': true,
      },
      RoomSocialMode.silent: {
        'chat': false,
        'reactions': false,
        'voice': false,
        'bubbles': false,
      },
      RoomSocialMode.focus: {
        'chat': false,
        'reactions': true,
        'voice': false,
        'bubbles': false,
      },
    };

    for (final entry in expected.entries) {
      final mode = entry.key;
      final features = entry.value;

      test('${mode.name}: chat=${features['chat']}, '
          'reactions=${features['reactions']}, '
          'voice=${features['voice']}, '
          'bubbles=${features['bubbles']}', () {
        expect(ChatRules.isChatAllowed(mode), features['chat']);
        expect(ChatRules.areReactionsAllowed(mode), features['reactions']);
        expect(ChatRules.isVoiceAllowed(mode), features['voice']);
        expect(ChatRules.areBubblesAllowed(mode), features['bubbles']);
      });
    }
  });
}
