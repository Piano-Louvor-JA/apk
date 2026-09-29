library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';

import 'stage_slide_painter.dart';

/// Persistência das personalizações do Palco (disk-backed, testável).
class StageSettingsRepository {
  final String scope;

  /// `global` preserva arquivo legado. Módulos usam seus próprios arquivos.
  StageSettingsRepository({this.scope = 'global'})
    : assert(
        scope == 'global' ||
            scope == 'hymns' ||
            scope == 'bible' ||
            scope == 'liturgy' ||
            scope == 'timer',
      );

  Future<File> _file() async {
    final name = scope == 'global'
        ? 'stage_settings.json'
        : 'stage_settings_$scope.json';
    return File('${(await getApplicationDocumentsDirectory()).path}/$name');
  }

  Future<StageSettings> load() async =>
      await loadOptional() ?? const StageSettings();

  /// Null = este módulo ainda não tem override e deve herdar o padrão global.
  Future<StageSettings?> loadOptional() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return StageSettings(
        backgroundColor: Color(j['bg'] as int? ?? 0xFF0A0E1A),
        textColor: Color(j['fg'] as int? ?? 0xFFFFFFFF),
        fontSize: (j['size'] as num?)?.toDouble() ?? 96,
        fontWeight: FontWeight.values.firstWhere(
          (w) => w.value == (j['weight'] as int? ?? 5),
          orElse: () => FontWeight.w600,
        ),
        margin: (j['margin'] as num?)?.toDouble() ?? 120,
        // F3.3m
        textShadow: j['tsOn'] as bool? ?? true,
        shadowBlur: (j['tsBlur'] as num?)?.toDouble() ?? 2.2,
        shadowIntensity: (j['tsInt'] as num?)?.toDouble() ?? 0.8,
        textBox: j['boxOn'] as bool? ?? false,
        boxOpacity: (j['boxBg'] as num?)?.toDouble() ?? 0.45,
        boxBorder: j['boxBorder'] as bool? ?? true,
        textAlign: j['tAlign'] as String? ?? 'center',
        textVerticalAlign: j['tVAlign'] as String? ?? 'middle',
        footerRefColor: Color(j['refColor'] as int? ?? 0xFFFCCE02),
        footerRefWeight: j['refWeight'] as int? ?? 600,
        showBibleVersion: j['showVer'] as bool? ?? true,
        // F3.3o
        bibleFontSize: (j['bSize'] as num?)?.toDouble() ?? 84,
        bibleFontWeight: j['bWeight'] as int? ?? 500,
        bibleTextColor: Color(j['bFg'] as int? ?? 0xFFFFFFFF),
      );
    } catch (_) {
      return const StageSettings();
    }
  }

  Future<void> save(StageSettings s) async {
    final f = await _file();
    await f.writeAsString(
      jsonEncode({
        'bg': s.backgroundColor.toARGB32(),
        'fg': s.textColor.toARGB32(),
        'size': s.fontSize,
        'weight': s.fontWeight.value,
        'margin': s.margin,
        // F3.3m
        'tsOn': s.textShadow,
        'tsBlur': s.shadowBlur,
        'tsInt': s.shadowIntensity,
        'boxOn': s.textBox,
        'boxBg': s.boxOpacity,
        'boxBorder': s.boxBorder,
        'tAlign': s.textAlign,
        'tVAlign': s.textVerticalAlign,
        'refColor': s.footerRefColor.toARGB32(),
        'refWeight': s.footerRefWeight,
        'showVer': s.showBibleVersion,
        // F3.3o
        'bSize': s.bibleFontSize,
        'bWeight': s.bibleFontWeight,
        'bFg': s.bibleTextColor.toARGB32(),
      }),
    );
  }

  /// Imagem de fundo personalizada copiada pro dir do app.
  Future<String?> saveBackgroundImage(
    String sourcePath, {
    String? backgroundScope,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = sourcePath.split('.').last.toLowerCase();
      final key = backgroundScope ?? scope;
      // Uma única fonte ativa POR escopo: JPG antigo não vence PNG oficial.
      await _clearBackgroundFiles(dir, key);
      final dest = File('${dir.path}/${_backgroundBase(key)}.$ext');
      await File(sourcePath).copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  /// Salva bytes de um BG empacotado (galeria oficial) no mesmo local do BG
  /// escolhido pelo usuário. Assim o resto do Palco continua agnóstico da fonte.
  Future<String?> saveBackgroundBytes(
    Uint8List bytes, {
    String ext = 'png',
    String? backgroundScope,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final key = backgroundScope ?? scope;
      await _clearBackgroundFiles(dir, key);
      final dest = File('${dir.path}/${_backgroundBase(key)}.$ext');
      await dest.writeAsBytes(bytes, flush: true);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  String _backgroundBase(String key) =>
      key == 'global' ? 'stage_bg' : 'stage_bg_$key';

  /// Apaga o JSON de settings deste escopo (override do módulo).
  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  /// Apaga a imagem de fundo deste escopo.
  Future<void> clearBackground() async {
    final dir = await getApplicationDocumentsDirectory();
    await _clearBackgroundFiles(dir, scope);
  }

  /// Só um background pode estar ativo por módulo.
  Future<void> _clearBackgroundFiles(Directory dir, String key) async {
    for (final ext in ['jpg', 'jpeg', 'png']) {
      final f = File('${dir.path}/${_backgroundBase(key)}.$ext');
      if (await f.exists()) await f.delete();
    }
  }

  Future<Uint8List?> loadBackgroundImage({String? backgroundScope}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final key = backgroundScope ?? scope;
      for (final ext in ['jpg', 'jpeg', 'png']) {
        final f = File('${dir.path}/${_backgroundBase(key)}.$ext');
        if (await f.exists()) return await f.readAsBytes();
      }
    } catch (_) {}
    return null;
  }
}
