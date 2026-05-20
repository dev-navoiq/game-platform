import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/main.dart' as app;
import 'package:flutter_app/core/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  group('Login Flow — Widget Integration', () {
    late MockSupabaseService mockSupabase;

    setUp(() {
      mockSupabase = MockSupabaseService();
    });

    testWidgets('guest login navigates to home screen', (tester) async {
      when(() => mockSupabase.signInAsGuest())
          .thenAnswer((_) async => 'guest-uid');
      when(() => mockSupabase.getProfile(userId: any(named: 'userId')))
          .thenAnswer((_) async => {'display_name': 'Guest', 'level': 1});

      await tester.pumpWidget(ProviderScope(
        overrides: [supabaseServiceProvider.overrideWithValue(mockSupabase)],
        child: const app.GamePlatformApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a Game'), findsOneWidget);
    });

    testWidgets('login form validates empty email', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [supabaseServiceProvider.overrideWithValue(mockSupabase)],
        child: const app.GamePlatformApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('login form validates invalid email format', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [supabaseServiceProvider.overrideWithValue(mockSupabase)],
        child: const app.GamePlatformApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email-field')), 'not-an-email');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('successful login shows home screen', (tester) async {
      when(() => mockSupabase.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => 'user-uid');
      when(() => mockSupabase.getProfile(userId: any(named: 'userId')))
          .thenAnswer((_) async => {'display_name': 'TestUser', 'level': 5});

      await tester.pumpWidget(ProviderScope(
        overrides: [supabaseServiceProvider.overrideWithValue(mockSupabase)],
        child: const app.GamePlatformApp(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('email-field')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('password-field')), 'password123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a Game'), findsOneWidget);
    });
  });
}
