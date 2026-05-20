import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/main.dart' as app;
import 'package:flutter_app/core/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

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
      when(() => mockSupabase.subscribeToRoom(
            roomId: any(named: 'roomId'),
            onUpdate: any(named: 'onUpdate'),
          )).thenReturn(null);

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
