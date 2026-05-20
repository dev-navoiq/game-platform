import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/shared/widgets/glass_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('GlassButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassButton(label: 'Start Game', onPressed: null),
      ));
      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('fires onPressed when enabled and tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(wrap(
        GlassButton(label: 'Go', onPressed: () => pressed = true),
      ));
      await tester.tap(find.byType(GlassButton));
      expect(pressed, isTrue);
    });

    testWidgets('does not fire onPressed when null (disabled)', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassButton(label: 'Disabled', onPressed: null),
      ));
      await tester.tap(find.byType(GlassButton));
      // No exception expected — just verifying it doesn't crash
    });

    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassButton(label: 'Wait', onPressed: null, isLoading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Wait'), findsNothing);
    });

    testWidgets('icon is rendered when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassButton(
          label: 'Play',
          onPressed: null,
          icon: Icon(Icons.play_arrow),
        ),
      ));
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('glass effect container is present', (tester) async {
      await tester.pumpWidget(wrap(
        const GlassButton(label: 'Test', onPressed: null),
      ));
      // GlassButton must wrap content in a Container or BackdropFilter
      expect(find.byType(Container), findsWidgets);
    });
  });
}
