import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/youtube_page.dart';

RemotePlayerState _state({bool youtube = false}) => RemotePlayerState(
  playing: false,
  position: Duration.zero,
  duration: Duration.zero,
  slideIndex: 0,
  slideCount: 0,
  volume: 80,
  canPrevious: false,
  canNext: false,
  youtubeCanPlay: youtube,
);

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

  testWidgets('YouTube aparece só para desktop que toca YouTube pelo remoto e abre a página em modo remoto', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Celular em pé: o 5º card fica na terceira linha da grade.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RemoteMoreHost(state: _state()))));
    expect(find.byKey(const Key('remote-more-youtube')), findsNothing);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RemoteMoreHost(state: _state(youtube: true)))));
    expect(find.byKey(const Key('remote-more-youtube')), findsOneWidget);
    expect(find.text('remote.youtube'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remote-more-youtube')));
    await tester.pumpAndSettle();
    final page = tester.widget<YoutubePage>(find.byType(YoutubePage));
    expect(page.remote, isTrue);
  });
}

class RemoteMoreHost extends StatelessWidget {
  const RemoteMoreHost({super.key, required this.state});
  final RemotePlayerState state;
  @override
  Widget build(BuildContext context) => RemoteMorePanel(state: state);
}
