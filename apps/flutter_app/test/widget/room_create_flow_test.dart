import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:flutter_app/features/lobby/models/room_member.dart';
import 'package:flutter_app/features/lobby/presentation/room_screen.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

RoomSnapshot _hostOnlySnapshot() => const RoomSnapshot(
      roomCode: 'ABC123',
      socialMode: 'full',
      status: 'waiting',
      gameType: 'twenty_nine',
      maxPlayers: 4,
      members: [
        RoomMember(
          id: 'guest-uid',
          displayName: 'You',
          seatIndex: 0,
          isHost: true,
          isBot: false,
          isReady: false,
          isCurrentUser: true,
        ),
      ],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_hostOnlySnapshot());
  });

  testWidgets(
      'optimistic create flow: paints "Creating…" immediately, then swaps in '
      'the real room once create-room returns', (tester) async {
    final mock = MockSupabaseService();
    // Hold create-room open so we can observe the optimistic state first.
    final create = Completer<Map<String, dynamic>>();
    when(() => mock.createRoom(
          gameType: any(named: 'gameType'),
          socialMode: any(named: 'socialMode'),
          maxPlayers: any(named: 'maxPlayers'),
        )).thenAnswer((_) => create.future);
    when(() => mock.fetchRoomSnapshot(roomId: any(named: 'roomId')))
        .thenAnswer((_) async => _hostOnlySnapshot());
    when(() => mock.subscribeToRoomMembership(
          roomId: any(named: 'roomId'),
          onChanged: any(named: 'onChanged'),
        )).thenReturn(() {});

    await tester.pumpWidget(ProviderScope(
      overrides: [supabaseServiceProvider.overrideWithValue(mock)],
      child: const MaterialApp(
        home: RoomScreen(
          roomId: 'pending',
          createRequest: RoomCreateRequest(
            gameType: 'twenty_nine',
            socialMode: 'full',
            maxPlayers: 4,
          ),
        ),
      ),
    ));
    await tester.pump(); // build + post-frame fires the background create

    // Optimistic table is on screen before the server has answered.
    expect(find.text('Creating…'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('ABC123'), findsNothing);

    // create-room resolves → screen binds to the real room and loads it.
    create.complete({'room_id': 'room-xyz', 'code': 'ABC123'});
    await tester.pumpAndSettle();

    expect(find.text('Creating…'), findsNothing);
    expect(find.text('ABC123'), findsOneWidget);
    // The room screen attached to the *real* id, not the 'pending' sentinel.
    verify(() => mock.fetchRoomSnapshot(roomId: 'room-xyz')).called(1);
    verify(() => mock.subscribeToRoomMembership(
          roomId: 'room-xyz',
          onChanged: any(named: 'onChanged'),
        )).called(1);
  });
}
