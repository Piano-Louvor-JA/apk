import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_mini_player_overlay.dart';

class _Session extends RemoteSession {
  final sent = <RemoteCommand>[];
  @override
  bool get isControlling => true;
  @override
  Future<void> send(RemoteCommand command) async => sent.add(command);
}

RemotePlayerState _state({bool projecting = false, int verse = 1}) =>
    RemotePlayerState(
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      slideIndex: 0,
      slideCount: 0,
      volume: 0,
      canPrevious: false,
      canNext: false,
      bibleModule: RemoteBibleState(
        bookId: 1,
        chapter: 1,
        versionId: 1,
        selectedVerses: [verse],
        isProjecting: projecting,
        verses: const {1: 'No princípio', 2: 'A terra'},
        books: const [
          RemoteBibleBook(id: 1, name: 'Gênesis', chapters: 50, number: 1),
        ],
        versions: const [RemoteBibleVersion(id: 1, abbreviation: 'ARA')],
      ),
    );

void main() {
  late _Session session;
  late GlobalKey<NavigatorState> navigator;
  setUp(() {
    session = _Session();
    navigator = GlobalKey<NavigatorState>();
    remoteBibleMinimized.value = false;
  });
  tearDown(() async {
    remoteBibleMinimized.value = false;
    await session.dispose();
  });

  Future<void> mount(WidgetTester tester, RemotePlayerState state) async {
    session.debugEmitStateForTest(state);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => RemoteMiniPlayerOverlay(
          navigatorKey: navigator,
          session: session,
          child: child!,
        ),
        home: Scaffold(body: RemoteBiblePanel(state: state)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'Bíblia minimiza, arrasta, navega, expande e projeta sem perder a seleção',
    (tester) async {
      await mount(tester, _state());
      await tester.ensureVisible(
        find.byKey(const Key('remote-bible-minimize')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remote-bible-minimize')));
      await tester.pumpAndSettle();
      final mini = find.byKey(const Key('remote-bible-mini'));
      expect(mini, findsOneWidget);
      expect(find.byKey(const Key('remote-bible-preview')), findsNothing);
      expect(session.sent, isEmpty);
      final before = tester.getTopLeft(mini);
      await tester.drag(mini, const Offset(-60, -80));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(mini).dx, lessThan(before.dx));
      expect(tester.getTopLeft(mini).dy, lessThan(before.dy));
      await tester.tap(find.byKey(const Key('remote-bible-preview-next')));
      expect(session.sent.single.action, RemoteAction.bibleSelectVerse);
      expect(session.sent.single.verse, 2);
      session.debugEmitStateForTest(_state(verse: 2));
      await tester.pumpAndSettle();
      expect(find.text('A terra'), findsOneWidget);
      await tester.tap(find.byKey(const Key('remote-bible-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote-bible-preview')), findsOneWidget);
      expect(mini, findsNothing);
      expect(session.sent, hasLength(1));
      await tester.tap(find.byKey(const Key('remote-bible-minimize')));
      await tester.pumpAndSettle();
      expect(mini, findsOneWidget);
      await tester.tap(find.byKey(const Key('remote-bible-mini-project')));
      expect(session.sent.last.action, RemoteAction.bibleOpen);
      expect(session.sent.last.verse, 2);
      await tester.tap(find.byKey(const Key('remote-bible-mini-close')));
      await tester.pumpAndSettle();
      expect(session.sent.last.action, RemoteAction.bibleClose);
      expect(mini, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bíblia projetando acompanha outras páginas e retorna à prévia original',
    (tester) async {
      await mount(tester, _state(projecting: true));
      expect(find.byKey(const Key('remote-bible-mini')), findsNothing);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra página')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote-bible-mini')), findsOneWidget);
      expect(find.text('No princípio'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote-bible-mini')), findsNothing);
      expect(find.byKey(const Key('remote-bible-preview')), findsOneWidget);
      expect(session.sent, isEmpty);
    },
  );
}
