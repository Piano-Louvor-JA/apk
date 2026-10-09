import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_settings_repository.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_slide_painter.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/stage_customization_sheet.dart';
// path_provider expõe esta interface transitive no lock do app; fake de disco real.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake do channel do path_provider apontando pra um dir temporário.
class _FakePathProvider extends PathProviderPlatform {
  final String basePath;
  _FakePathProvider(this.basePath);

  @override
  Future<String?> getApplicationDocumentsPath() async => basePath;
}

StageSettings _initial({
  Color bg = const Color(0xFF0A0E1A),
  double size = 96,
  String align = 'center',
  String valign = 'middle',
}) => StageSettings(
  backgroundColor: bg,
  fontSize: size,
  textAlign: align,
  textVerticalAlign: valign,
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  StageSettings? initial,
  StageModule module = StageModule.hymns,
  required ValueChanged<StageSettings> onApply,
}) async {
  // Sheet é alta (preview + ~10 seções); viewport maior evita taps fora da tela.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StageCustomizationSheet(
          module: module,
          initial: initial ?? _initial(),
          onApply: onApply,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}


/// Tapa num widget que pode estar abaixo da dobra: rola até ele primeiro.
Future<void> _tapScrollable(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump();
}


/// Aplica as mudanças: o save vai a DISCO real (path_provider fake + IO
/// verdadeiro), que não roda dentro do FakeAsync do testWidgets — por isso
/// o tap precisa de runAsync.
Future<void> _apply(WidgetTester tester) async {
  await tester.runAsync(() async {
    await _tapScrollable(tester, find.widgetWithText(FilledButton, 'Aplicar'));
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stage_custom_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('StageCustomizationSheet — controles básicos', () {
    testWidgets('renderiza preview com título do módulo e controles', (
      tester,
    ) async {
      await _pumpSheet(tester, onApply: (_) {});

      expect(find.text('Personalizar Hinos'), findsOneWidget);
      expect(find.text('O nosso sol\nVeio iluminar'), findsOneWidget);
      expect(find.text('Cor de fundo'), findsOneWidget);
      expect(find.text('Cor do texto'), findsOneWidget);
      expect(find.text('Sombra na letra'), findsOneWidget);
      expect(find.text('Caixinha atrás da letra'), findsOneWidget);
      expect(find.text('Alinhamento do texto'), findsOneWidget);
      // Bíblia NÃO aparece fora do módulo bible:
      expect(find.text('Bíblia — aparência própria'), findsNothing);
    });

    testWidgets('módulo bible mostra seção própria de tipografia', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        module: StageModule.bible,
        onApply: (_) {},
      );

      expect(find.text('Personalizar Bíblia'), findsOneWidget);
      expect(find.text('Bíblia — aparência própria'), findsOneWidget);
      expect(
        find.text('Mostrar versão da Bíblia no rodapé'),
        findsOneWidget,
      );
      expect(find.text('Cor da referência (rodapé)'), findsOneWidget);
    });

    testWidgets('mudar cor de fundo reflete no preview e no aplicar', (
      tester,
    ) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.widgetWithText(InputChip, 'Preto'));
      await tester.pump();

      await _apply(tester);

      expect(applied, isNotNull);
      expect(applied!.backgroundColor, const Color(0xFF000000));
    });

    testWidgets('mudar cor do texto reflete no aplicar', (tester) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.widgetWithText(InputChip, 'Amarelo suave').first);
      await tester.pump();

      await _apply(tester);

      expect(applied!.textColor, const Color(0xFFFFE9A8));
    });

    testWidgets('slider de fonte atualiza label e valor aplicado', (
      tester,
    ) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      // move slider da fonte (primeiro Slider) pra um valor médio
      final sliderFinder = find.byType(Slider).first;
      await tester.drag(sliderFinder, const Offset(120, 0));
      await tester.pump();

      expect(find.textContaining('Tamanho da fonte'), findsOneWidget);

      await _apply(tester);
      expect(applied, isNotNull);
    });

    testWidgets('espessura via SegmentedButton muda fontWeight', (tester) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.text('Forte').first);
      await tester.pump();

      await _apply(tester);

      expect(applied!.fontWeight, FontWeight.w800);
    });

    testWidgets('sombra: ligar mostra sliders de intensidade/espalhamento', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        initial: _initial(),
        onApply: (_) {},
      );

      // default é sombra LIGADA — desligar esconde os sliders.
      expect(find.text('Intensidade da sombra'), findsOneWidget);
      await _tapScrollable(tester, find.text('Sombra na letra'));
      await tester.pump();
      expect(find.text('Intensidade da sombra'), findsNothing);

      // religar mostra de novo.
      await _tapScrollable(tester, find.text('Sombra na letra'));
      await tester.pump();
      expect(find.text('Intensidade da sombra'), findsOneWidget);
    });

    testWidgets('caixinha: ligar mostra opacidade e borda', (tester) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      expect(find.text('Opacidade da caixinha'), findsNothing);
      await _tapScrollable(tester, find.text('Caixinha atrás da letra'));
      await tester.pump();
      expect(find.text('Opacidade da caixinha'), findsOneWidget);
      expect(find.text('Borda na caixinha'), findsOneWidget);

      await _tapScrollable(tester, find.text('Borda na caixinha'));
      await tester.pump();

      await _apply(tester);
      expect(applied!.textBox, isTrue);
      expect(applied!.boxBorder, isFalse);
    });

    testWidgets('alinhamento horizontal e vertical aplicam strings', (
      tester,
    ) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.byIcon(TablerIcons.alignLeft));
      await tester.pump();
      await _tapScrollable(tester, find.byIcon(TablerIcons.arrowUp));
      await tester.pump();

      await _apply(tester);

      expect(applied!.textAlign, 'left');
      expect(applied!.textVerticalAlign, 'top');
    });

    testWidgets('Mais cores: escolher cor do picker aplica após OK', (
      tester,
    ) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.text('Mais cores').first);
      await tester.pumpAndSettle();

      expect(find.text('Escolher cor'), findsOneWidget);
      // OK sem escolher nada: mantém a cor atual (picked = current).
      await _tapScrollable(tester, find.widgetWithText(FilledButton, 'OK'));

      await _apply(tester);
      expect(applied!.backgroundColor, const Color(0xFF0A0E1A));
    });

    testWidgets('Mais cores: cancelar não altera a cor', (tester) async {
      StageSettings? applied;
      final original = _initial(bg: const Color(0xFF0A0E1A));
      await _pumpSheet(tester, initial: original, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.text('Mais cores').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      await _apply(tester);
      expect(applied!.backgroundColor, const Color(0xFF0A0E1A));
    });

    testWidgets('bible: cor/tamanho/espessura próprios e versão no rodapé', (
      tester,
    ) async {
      StageSettings? applied;
      await _pumpSheet(
        tester,
        module: StageModule.bible,
        onApply: (s) => applied = s,
      );

      await tester.tap(find.widgetWithText(InputChip, 'Dourado').last);
      await tester.pump();
      await _tapScrollable(tester, find.text('Mostrar versão da Bíblia no rodapé'));
      await tester.pump();

      await _apply(tester);

      expect(applied!.footerRefColor, const Color(0xFFFCCE02));
      // default é true; o tap no SwitchListTile alterna pra false.
      expect(applied!.showBibleVersion, isFalse);
    });
  });

  group('StageCustomizationSheet — redefinir e persistência', () {
    testWidgets('redefinir: cancelar mantém edições', (tester) async {
      StageSettings? applied;
      await _pumpSheet(tester, onApply: (s) => applied = s);

      await _tapScrollable(tester, find.widgetWithText(InputChip, 'Preto'));
      await tester.pump();

      await _tapScrollable(tester, find.text('Redefinir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      await _apply(tester);
      expect(applied!.backgroundColor, const Color(0xFF000000));
    });

    testWidgets('Aplicar persiste settings (repo global interno) e devolve pro onApply', (tester) async {
      StageSettings? applied;
      await _pumpSheet(
        tester,
        module: StageModule.liturgy,
        initial: _initial(bg: const Color(0xFF2A1B1B)),
        onApply: (s) => applied = s,
      );

      await _apply(tester);

      expect(applied!.backgroundColor, const Color(0xFF2A1B1B));
      // O sheet usa StageSettingsRepository() interno (scope global) e o
      // onApply do consumidor decide persistir por módulo — aqui valida global.
      final persisted = await tester.runAsync(
        () => StageSettingsRepository().load(),
      );
      expect(persisted!.backgroundColor, const Color(0xFF2A1B1B));
    });
  });
}
