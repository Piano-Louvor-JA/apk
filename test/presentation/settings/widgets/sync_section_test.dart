library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/sync_section.dart';

void main() {
  Widget subject({bool busy = false}) => MaterialApp(
    home: Scaffold(
      body: SyncSection(
        busy: busy,
        onExport: () async {},
        onImport: () async {},
      ),
    ),
  );

  testWidgets('renderiza botões de export/import e dispara handlers', (
    tester,
  ) async {
    var exported = false;
    var imported = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncSection(
            onExport: () async => exported = true,
            onImport: () async => imported = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sync-export')), findsOneWidget);
    expect(find.byKey(const Key('sync-import')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync-export')));
    await tester.tap(find.byKey(const Key('sync-import')));
    await tester.pump();
    expect(exported, isTrue);
    expect(imported, isTrue);
  });

  testWidgets('busy desabilita os botões', (tester) async {
    var exported = false;
    await tester.pumpWidget(subject(busy: true));
    await tester.tap(find.byKey(const Key('sync-export')), warnIfMissed: false);
    await tester.pump();
    final btn = tester.widget<OutlinedButton>(
      find.byKey(const Key('sync-export')),
    );
    expect(btn.onPressed, isNull);
    expect(exported, isFalse);
  });
}
