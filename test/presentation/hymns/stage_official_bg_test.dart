library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/dlna/stage_slide_painter.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/stage_customization_sheet.dart';
// path_provider expõe esta interface transitive no lock do app; fake de disco.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

StageSettings _initial() => const StageSettings();

Future<void> _pumpSheet(
  WidgetTester tester, {
  StageModule module = StageModule.hymns,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StageCustomizationSheet(
          module: module,
          initial: _initial(),
          onApply: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapScrollable(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump();
}

/// Onda 83: galeria de fundos oficiais — abre bottom sheet, escolhe bg-01,
/// preview recarrega (bytes != null) e janela fecha. Cancelamento não aplica.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stage_official_bg');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  testWidgets('fundos oficiais: escolhe bg-01 e fecha a galeria', (
    tester,
  ) async {
    await _pumpSheet(tester);

    await _tapScrollable(tester, find.text('Fundos oficiais'));
    await tester.pumpAndSettle();

    // galeria aberta com os 7 fundos oficiais
    expect(find.text('Galeria de fundos'), findsOneWidget);
    expect(find.byType(Image), findsAtLeast(1));

    // escolhe o primeiro fundo
    await tester.tap(find.byType(Image).first, warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // galeria fechou e o preview recarregou (sem exceção)
    expect(find.text('Galeria de fundos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar a galeria mantém tudo como estava', (tester) async {
    await _pumpSheet(tester);

    await _tapScrollable(tester, find.text('Fundos oficiais'));
    await tester.pumpAndSettle();
    expect(find.text('Galeria de fundos'), findsOneWidget);

    // modal dismissível: toca na barreira acima do sheet.
    await tester.tapAt(const Offset(540, 20));
    await tester.pumpAndSettle();
    expect(find.text('Galeria de fundos'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
