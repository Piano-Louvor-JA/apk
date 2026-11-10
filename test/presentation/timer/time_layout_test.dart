import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/presentation/timer/timer_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Tempo mostra três cartões recolhidos e mantém cronômetro ao recolher',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: TimerPage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stopwatch-display')), findsOneWidget);
      expect(find.byKey(const Key('countdown-display')), findsOneWidget);
      expect(find.byKey(const Key('clock-display')), findsOneWidget);
      expect(find.byKey(const Key('stopwatch-toggle')), findsNothing);
      expect(find.byKey(const Key('countdown-start')), findsNothing);
      expect(find.byKey(const Key('clock-format')), findsNothing);
      expect(
        tester.getBottomLeft(find.byKey(const Key('clock-display'))).dy,
        lessThan(800),
      );
      await tester.tap(find.text('timer.stopwatch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stopwatch-toggle')));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('timer.stopwatch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('stopwatch-toggle')), findsNothing);
      await tester.tap(find.text('timer.stopwatch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('common.pause'), findsOneWidget);
      await tester.tap(find.text('timer.stopwatch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('timer.countdown'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('countdown-start')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets('relógio permite trocar formato sem iniciar cronômetro', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TimerPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('timer.clock'));
    await tester.tap(find.text('timer.clock'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('clock-format')));
    await tester.tap(find.byKey(const Key('clock-format')));
    await tester.pumpAndSettle();
    final display = tester.widget<Text>(find.byKey(const Key('clock-display')));
    expect(display.data, matches(RegExp(r'^\d{2}:\d{2}:\d{2} (AM|PM)$')));
    expect(find.byKey(const Key('stopwatch-toggle')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

}
