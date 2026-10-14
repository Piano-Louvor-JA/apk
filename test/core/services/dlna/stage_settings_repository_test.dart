import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_settings_repository.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_slide_painter.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stage_settings_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('StageSettingsRepository — persistência real em disco', () {
    test('load sem arquivo → null (módulo herda global) e load → default', () async {
      final repo = StageSettingsRepository(scope: 'hymns');
      expect(await repo.loadOptional(), isNull);
      final defaults = await repo.load();
      expect(defaults.fontSize, 96);
      expect(defaults.textAlign, 'center');
    });

    test('save+load round-trip preserva todos os campos F3.3m/F3.3o', () async {
      final repo = StageSettingsRepository(scope: 'bible');
      const settings = StageSettings(
        backgroundColor: Color(0xFF010203),
        textColor: Color(0xFF040506),
        fontSize: 120,
        fontWeight: FontWeight.w800,
        margin: 90,
        textShadow: false,
        shadowBlur: 5.5,
        shadowIntensity: 0.3,
        textBox: true,
        boxOpacity: 0.75,
        boxBorder: false,
        textAlign: 'right',
        textVerticalAlign: 'bottom',
        footerRefColor: Color(0xFF0A0B0C),
        footerRefWeight: 400,
        showBibleVersion: false,
        bibleFontSize: 60,
        bibleFontWeight: 300,
        bibleTextColor: Color(0xFF0D0E0F),
      );
      await repo.save(settings);
      final loaded = await repo.loadOptional();
      expect(loaded, isNotNull);
      expect(loaded!.backgroundColor, const Color(0xFF010203));
      expect(loaded.textColor, const Color(0xFF040506));
      expect(loaded.fontSize, 120);
      expect(loaded.fontWeight, FontWeight.w800);
      expect(loaded.margin, 90);
      expect(loaded.textShadow, isFalse);
      expect(loaded.shadowBlur, 5.5);
      expect(loaded.shadowIntensity, 0.3);
      expect(loaded.textBox, isTrue);
      expect(loaded.boxOpacity, 0.75);
      expect(loaded.boxBorder, isFalse);
      expect(loaded.textAlign, 'right');
      expect(loaded.textVerticalAlign, 'bottom');
      expect(loaded.footerRefColor, const Color(0xFF0A0B0C));
      expect(loaded.footerRefWeight, 400);
      expect(loaded.showBibleVersion, isFalse);
      expect(loaded.bibleFontSize, 60);
      expect(loaded.bibleFontWeight, 300);
      expect(loaded.bibleTextColor, const Color(0xFF0D0E0F));
    });

    test('scopes escrevem arquivos distintos; global usa nome legado', () async {
      final global = StageSettingsRepository();
      final hymns = StageSettingsRepository(scope: 'hymns');
      await global.save(
        const StageSettings(fontSize: 80),
      );
      await hymns.save(const StageSettings(fontSize: 140));
      expect(
        jsonDecode(File('${tmp.path}/stage_settings.json').readAsStringSync())['size'],
        80,
      );
      expect(
        jsonDecode(
          File('${tmp.path}/stage_settings_hymns.json').readAsStringSync(),
        )['size'],
        140,
      );
      expect((await global.load()).fontSize, 80);
      expect((await hymns.load()).fontSize, 140);
    });

    test('arquivo com JSON corrompido → defaults (catch do loadOptional)',
        () async {
      await File(
        '${tmp.path}/stage_settings_liturgy.json',
      ).writeAsString('{"size": 12');
      final repo = StageSettingsRepository(scope: 'liturgy');
      final loaded = await repo.loadOptional();
      expect(loaded, isNotNull);
      expect(loaded!.fontSize, 96);
    });

    test('JSON com tipos errados → defaults por campo (num?/String?/bool?)',
        () async {
      await File('${tmp.path}/stage_settings_timer.json').writeAsString(
        jsonEncode({
          'size': 'não-é-número',
          'weight': 999,
          'tAlign': 42,
          'tsOn': 'sim',
          'bg': 'cor inválida',
        }),
      );
      final repo = StageSettingsRepository(scope: 'timer');
      final loaded = await repo.loadOptional();
      expect(loaded, isNotNull);
      expect(loaded!.fontSize, 96);
      expect(loaded.fontWeight, FontWeight.w600);
      expect(loaded.textAlign, 'center');
      expect(loaded.textShadow, isTrue);
      // 'cor inválida' não é int → j['bg'] as int? lança → catch externo → default.
      // (comportamento atual: erro de cast no bg cai no catch e retorna default)
      expect(loaded.backgroundColor, const Color(0xFF0A0E1A));
    });

    test('weight desconhecido (999 válido como int) cai no orElse w600',
        () async {
      await File(
        '${tmp.path}/stage_settings.json',
      ).writeAsString(jsonEncode({'weight': 999, 'size': 100}));
      final repo = StageSettingsRepository();
      final loaded = await repo.load();
      expect(loaded.fontWeight, FontWeight.w600);
      expect(loaded.fontSize, 100);
    });
  });

  group('StageSettingsRepository — imagem de fundo (BG por escopo)', () {
    test('saveBackgroundBytes + loadBackgroundImage round-trip', () async {
      final repo = StageSettingsRepository(scope: 'hymns');
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final path = await repo.saveBackgroundBytes(bytes);
      expect(path, isNotNull);
      expect(path, endsWith('stage_bg_hymns.png'));
      expect(File(path!).existsSync(), isTrue);
      final loaded = await repo.loadBackgroundImage();
      expect(loaded, bytes);
    });

    test('saveBackgroundBytes com backgroundScope específico', () async {
      final repo = StageSettingsRepository();
      final path = await repo.saveBackgroundBytes(
        Uint8List.fromList([9, 9]),
        ext: 'jpg',
        backgroundScope: 'bible',
      );
      expect(path, endsWith('stage_bg_bible.jpg'));
      expect(
        await repo.loadBackgroundImage(backgroundScope: 'bible'),
        Uint8List.fromList([9, 9]),
      );
      // scope global continua vazio:
      expect(await repo.loadBackgroundImage(), isNull);
    });

    test('troca de BG no mesmo escopo apaga extensões antigas (um ativo)',
        () async {
      final repo = StageSettingsRepository();
      final old = await repo.saveBackgroundBytes(
        Uint8List.fromList([1]),
        ext: 'jpg',
      );
      expect(old, endsWith('.jpg'));
      final novo = await repo.saveBackgroundBytes(Uint8List.fromList([2]));
      expect(novo, endsWith('.png'));
      expect(File(old!).existsSync(), isFalse); // jpg antigo removido
      expect(await repo.loadBackgroundImage(), Uint8List.fromList([2]));
    });

    test('saveBackgroundImage copia arquivo de origem', () async {
      final src = File('${tmp.path}/origem.png');
      await src.writeAsBytes([7, 7, 7]);
      final repo = StageSettingsRepository(scope: 'liturgy');
      final dest = await repo.saveBackgroundImage(src.path);
      expect(dest, endsWith('stage_bg_liturgy.png'));
      expect(File(dest!).readAsBytesSync(), [7, 7, 7]);
    });

    test('saveBackgroundImage com origem inexistente → null (catch)',
        () async {
      final repo = StageSettingsRepository();
      expect(
        await repo.saveBackgroundImage('${tmp.path}/fantasma.xyz'),
        isNull,
      );
    });

    test('clear apaga o JSON do escopo; loadOptional volta a null', () async {
      final repo = StageSettingsRepository(scope: 'hymns');
      await repo.save(const StageSettings(fontSize: 70));
      expect(await repo.loadOptional(), isNotNull);
      await repo.clear();
      expect(await repo.loadOptional(), isNull);
    });

    test('clearBackground apaga imagem do escopo', () async {
      final repo = StageSettingsRepository(scope: 'timer');
      await repo.saveBackgroundBytes(Uint8List.fromList([1]));
      expect(await repo.loadBackgroundImage(), isNotNull);
      await repo.clearBackground();
      expect(await repo.loadBackgroundImage(), isNull);
    });
  });
}
