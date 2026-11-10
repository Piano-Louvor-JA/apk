import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_announcements_panel.dart';

void main() {
  const state = RemoteAnnouncementsState(
    activeListId: 'l1',
    lists: [
      RemoteAnnouncementList(
        id: 'l1',
        name: 'Avulsa',
        items: [
          RemoteAnnouncement(
            id: 'a1',
            title: 'Reunião',
            kind: 'text',
            text: 'Sábado',
            inCarousel: true,
          ),
          RemoteAnnouncement(
            id: 'v1',
            title: 'Vídeo',
            kind: 'video',
            fileName: 'aviso.mp4',
          ),
        ],
      ),
      RemoteAnnouncementList(id: 'l2', name: 'Outra', items: []),
    ],
    status: 'playing',
    slideCount: 3,
    previewTitle: 'Reunião',
    previewText: 'Sábado',
  );
  testWidgets(
    'espelha lista e envia comandos de abertura, carrossel e participação',
    (tester) async {
      final sent = <RemoteCommand>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteAnnouncementsPanel(
              state: state,
              send: (cmd) async => sent.add(cmd),
            ),
          ),
        ),
      );
      expect(find.text('Avulsa'), findsOneWidget);
      expect(find.text('aviso.mp4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('announcement-open-a1')));
      expect(sent.last.action, RemoteAction.announcementsOpen);
      expect(sent.last.targetId, 'a1');
      await tester.tap(find.byKey(const Key('announcement-include-a1')));
      expect(sent.last.action, RemoteAction.announcementsInclude);
      expect(sent.last.enabled, isFalse);
      await tester.ensureVisible(find.byKey(const Key('announcements-pause')));
      await tester.tap(find.byKey(const Key('announcements-pause')));
      expect(sent.last.action, RemoteAction.announcementsPause);
      await tester.ensureVisible(find.byKey(const Key('announcements-loop')));
      await tester.tap(find.byKey(const Key('announcements-loop')));
      expect(sent.last.enabled, isFalse);
      expect(sent.last.action, RemoteAction.announcementsSetCarousel);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('peer antigo não causa erro e orienta atualizar desktop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RemoteAnnouncementsPanel())),
    );
    expect(find.text('remote.announcements.unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('seleciona outra lista e altera intervalo validando o limite', (tester) async {
    final sent = <RemoteCommand>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RemoteAnnouncementsPanel(state: state, send: (cmd) async => sent.add(cmd)))));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outra').last);
    await tester.pumpAndSettle();
    expect(sent.last.action, RemoteAction.announcementsSelectList);
    expect(sent.last.targetId, 'l2');
    await tester.ensureVisible(find.byKey(const Key('announcements-duration')));
    await tester.tap(find.byKey(const Key('announcements-duration')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('announcements-seconds-input')), '1');
    await tester.tap(find.text('common.save'));
    await tester.pump();
    expect(find.text('remote.announcements.durationRange'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('announcements-seconds-input')), '10');
    await tester.tap(find.text('common.save'));
    await tester.pumpAndSettle();
    expect(sent.last.action, RemoteAction.announcementsSetCarousel);
    expect(sent.last.durationMs, 10000);
    expect(tester.takeException(), isNull);
  });

}
