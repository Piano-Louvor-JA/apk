import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';

void main() {
  testWidgets('Mais mostra blocos e abre Tempo, Sorteio e Anúncios com retorno à grade', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RemoteMorePanel())));
    expect(find.byType(GridView), findsOneWidget);
    expect((tester.widget<GridView>(find.byType(GridView)).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 2);
    expect(find.byKey(const Key('remote-more-announcements')), findsOneWidget);
    expect(find.byKey(const Key('remote-more-sabbath')), findsOneWidget);
    expect(find.text('remote.tabTime'), findsOneWidget);
    expect(find.text('remote.random.title'), findsOneWidget);
    expect(find.byKey(const Key('remote-timer-card')), findsNothing);
    expect(find.byKey(const Key('remote-random-min')), findsNothing);
    await tester.tap(find.byKey(const Key('remote-more-time')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote-timer-card')), findsOneWidget);
    expect(find.byKey(const Key('remote-countdown-card')), findsOneWidget);
    expect(find.byKey(const Key('remote-clock-expand')), findsOneWidget);
    expect(find.byKey(const Key('remote-more-random')), findsNothing);
    await tester.tap(find.byKey(const Key('remote-more-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remote-more-random')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote-random-min')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-more-back')));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byKey(const Key('remote-random-min')), findsNothing);
    await tester.tap(find.byKey(const Key('remote-more-announcements')));
    await tester.pumpAndSettle();
    expect(find.text('remote.announcements.unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-more-back')));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
