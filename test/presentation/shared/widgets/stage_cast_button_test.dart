import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';
// path_provider exposto transitivo no lock do app; fake de disco real.
import 'package:flutter/services.dart';
// path_provider exposto transitivo no lock do app; fake de disco real.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cast_btn_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    // Mock do channel direto: callbacks do widget (IO real) precisam disso
    // dentro do FakeAsync — a platform interface fake resolve só chamadas
    // diretas, não os handlers internos do plugin.
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tmp.path);
  });

  tearDown(() async {
    final stage = StageSession.instance;
    await stage.turnOff();
    await PalcoOrchestrator.instance.removeSlot('principal');
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('StageClearButton', () {
    testWidgets('palco desligado: não renderiza nada', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(appBar: AppBar(actions: [StageClearButton()]))),
      );
      await tester.pump();

      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(TablerIcons.eraser), findsNothing);
    });
  });

  group('StageCastButton', () {
    testWidgets('palco desligado: ícone castOff; tap abre auto-connect', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(appBar: AppBar(actions: [StageCastButton()]))),
      );
      await tester.pump();

      final btn = find.byIcon(TablerIcons.castOff);
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // sheet de auto-conexão aberto com spinner de scan (nunca settle) —
      // sem TV não conecta; valida apenas que não crasha
      expect(tester.takeException(), isNull);
    });
  });
}
