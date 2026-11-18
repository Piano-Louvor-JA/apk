import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_sabbath_panel.dart';

void main() {
  testWidgets('contagem e áudio enviam comandos ao desktop', (tester) async {
    final sent = <RemoteCommand>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteSabbathPanel(
            state: const RemoteSabbathState(
              remainingMs: 2700000,
              canStart: true,
              hasOpening: true,
            ),
            send: (cmd) async => sent.add(cmd),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.byKey(const Key('sabbath-remaining'))).data, '45:00');
    await tester.tap(find.byKey(const Key('sabbath-play')));
    expect(sent.last.action, RemoteAction.sabbathStart);
    await tester.tap(find.byKey(const Key('sabbath-projection')));
    expect(sent.last.action, RemoteAction.sabbathToggleProjection);
    await tester.ensureVisible(find.byKey(const Key('sabbath-opening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sabbath-opening')));
    expect(sent.last.action, RemoteAction.sabbathToggleOpening);
    await tester.ensureVisible(find.byKey(const Key('sabbath-muted')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sabbath-muted')));
    expect(sent.last.action, RemoteAction.sabbathSetMuted);
    expect(sent.last.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('contagem em curso pausa e atualiza tempo e projeção', (
    tester,
  ) async {
    final sent = <RemoteCommand>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteSabbathPanel(
            state: const RemoteSabbathState(
              status: 'running',
              remainingMs: 120000,
              isProjecting: true,
            ),
            send: (cmd) async => sent.add(cmd),
          ),
        ),
      ),
    );
    expect(find.text('02:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sabbath-play')));
    expect(sent.last.action, RemoteAction.sabbathPause);
    await tester.tap(find.byKey(const Key('sabbath-plus-minute')));
    expect(sent.last.action, RemoteAction.sabbathAdjustTime);
    expect(sent.last.index, 60000);
    expect(find.text('remote.stopProjection'), findsOneWidget);
  });
  testWidgets('nome do arquivo aparece apenas no modo vídeo personalizado', (
    tester,
  ) async {
    for (final mode in ['duration', 'endOnly', 'video']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteSabbathPanel(
              state: RemoteSabbathState(
                scheduleMode: mode,
                videoName: 'Escola Sabatina.mp4',
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Escola Sabatina.mp4'),
        mode == 'video' ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets(
    'horário tem aparência de campo editável e abre edição ao tocar',
    (tester) async {
      final sent = <RemoteCommand>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteSabbathPanel(
              state: const RemoteSabbathState(
                scheduleMode: 'endOnly',
                endTime: '16:30',
              ),
              send: (command) async => sent.add(command),
            ),
          ),
        ),
      );
      final field = find.byKey(const Key('sabbath-end-time'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(find.text('remote.sabbath.tapToEdit'), findsOneWidget);
      expect(
        find.descendant(of: field, matching: find.byType(TextFormField)),
        findsOneWidget,
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(input, '17:00');
      await tester.tap(find.text('common.save'));
      await tester.pumpAndSettle();
      expect(sent.single.action, RemoteAction.sabbathSetSchedule);
      expect(sent.single.name, '17:00');
    },
  );
}
