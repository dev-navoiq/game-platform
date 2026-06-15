import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/main.dart' as app;
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:flutter_app/features/lobby/models/room_member.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

RoomSnapshot _snapshotWith({required int memberCount, String code = 'ABC123'}) {
  return RoomSnapshot(
    roomCode: code,
    socialMode: 'full',
    status: 'waiting',
    gameType: 'twenty_nine',
    maxPlayers: 4,
    members: [
      const RoomMember(
        id: 'guest-uid',
        displayName: 'You',
        seatIndex: 0,
        isHost: true,
        isBot: false,
        isReady: false,
        isCurrentUser: true,
      ),
      if (memberCount >= 2)
        const RoomMember(
          id: 'bot-uid',
          displayName: 'Bot',
          seatIndex: 1,
          isHost: false,
          isBot: true,
          isReady: true,
          isCurrentUser: false,
          botDifficulty: 'medium',
        ),
    ],
  );
}

void main() {
  group('Room Creation Flow — Widget Integration', () {
    late MockSupabaseService mockSupabase;

    setUp(() {
      mockSupabase = MockSupabaseService();
      // Stub guest auth so we can reach the lobby
      when(() => mockSupabase.signInAsGuest())
          .thenAnswer((_) async => 'guest-uid');
      when(() => mockSupabase.getProfile(userId: any(named: 'userId')))
          .thenAnswer((_) async => {'display_name': 'Guest', 'level': 1});
      // Default room roster: just the host. Tests that need a different
      // shape (e.g. after add-bot) override fetchRoomSnapshot below.
      when(() => mockSupabase.fetchRoomSnapshot(roomId: any(named: 'roomId')))
          .thenAnswer((_) async => _snapshotWith(memberCount: 1));
      when(() => mockSupabase.subscribeToRoomMembership(
            roomId: any(named: 'roomId'),
            onChanged: any(named: 'onChanged'),
          )).thenReturn(() {});
    });

    Future<void> loginAsGuest(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [supabaseServiceProvider.overrideWithValue(mockSupabase)],
        child: const app.GamePlatformApp(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
    }

    testWidgets('can navigate to Twenty-Nine lobby', (tester) async {
      await loginAsGuest(tester);
      await tester.tap(find.text('Twenty-Nine'));
      await tester.pumpAndSettle();
      expect(find.text('Twenty-Nine Lobby'), findsOneWidget);
    });

    testWidgets('can create a room from lobby', (tester) async {
      when(() => mockSupabase.createRoom(
            gameType: any(named: 'gameType'),
            socialMode: any(named: 'socialMode'),
          )).thenAnswer((_) async => <String, dynamic>{'room_id': 'room-xyz', 'code': 'ABC123'});
      when(() => mockSupabase.subscribeToRoom(
            roomId: any(named: 'roomId'),
            onUpdate: any(named: 'onUpdate'),
          )).thenReturn(null);

      await loginAsGuest(tester);
      await tester.tap(find.text('Twenty-Nine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Room'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('room-screen')), findsOneWidget);
      expect(find.byKey(const Key('room-code')), findsOneWidget);
    });

    testWidgets('can add bots to the room', (tester) async {
      when(() => mockSupabase.createRoom(
            gameType: any(named: 'gameType'),
            socialMode: any(named: 'socialMode'),
          )).thenAnswer((_) async => <String, dynamic>{'room_id': 'room-xyz', 'code': 'ABC123'});
      when(() => mockSupabase.addBot(
            roomId: any(named: 'roomId'),
            difficulty: any(named: 'difficulty'),
          )).thenAnswer((_) async => 'bot-uid');
      // Override the setUp default — after add-bot we want fetchRoomSnapshot
      // to report host + bot. The realtime subscription is stubbed no-op so
      // the test doesn't depend on the onChanged() round-trip; we just need
      // the screen's next pumpAndSettle to read the updated roster.
      when(() => mockSupabase.fetchRoomSnapshot(roomId: any(named: 'roomId')))
          .thenAnswer((_) async => _snapshotWith(memberCount: 2));

      await loginAsGuest(tester);
      await tester.tap(find.text('Twenty-Nine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Room'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Bot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('player-slot')), findsNWidgets(2));
    });

    testWidgets('social mode can be changed in room settings', (tester) async {
      when(() => mockSupabase.createRoom(
            gameType: any(named: 'gameType'),
            socialMode: any(named: 'socialMode'),
          )).thenAnswer((_) async => <String, dynamic>{'room_id': 'room-xyz', 'code': 'ABC123'});
      when(() => mockSupabase.updateRoomSocialMode(
            roomId: any(named: 'roomId'),
            mode: any(named: 'mode'),
          )).thenAnswer((_) async {});
      when(() => mockSupabase.subscribeToRoom(
            roomId: any(named: 'roomId'),
            onUpdate: any(named: 'onUpdate'),
          )).thenReturn(null);

      await loginAsGuest(tester);
      await tester.tap(find.text('Twenty-Nine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Room'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('room-settings-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silent'));
      await tester.pumpAndSettle();

      verify(() => mockSupabase.updateRoomSocialMode(
            roomId: 'room-xyz',
            mode: 'silent',
          )).called(1);
    });
  });
}
