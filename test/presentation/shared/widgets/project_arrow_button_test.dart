import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/project_arrow_button.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool projecting,
    required VoidCallback onPressed,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ProjectArrowButton(
            projecting: projecting,
            onPressed: onPressed,
          ),
        ),
      ),
    ),
  );

  testWidgets('pulsa enquanto não projeta e chama ao tocar', (tester) async {
    var taps = 0;
    await pump(tester, projecting: false, onPressed: () => taps++);
    expect(find.byKey(const Key('project-arrow-pulse')), findsOneWidget);
    expect(find.byTooltip('remote.project'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-arrow')));
    expect(taps, 1);
  });

  testWidgets('projetando: para de pulsar e oferece parar', (tester) async {
    await pump(tester, projecting: true, onPressed: () {});
    expect(find.byKey(const Key('project-arrow-pulse')), findsNothing);
    expect(find.byTooltip('remote.stopProjection'), findsOneWidget);
  });
}
