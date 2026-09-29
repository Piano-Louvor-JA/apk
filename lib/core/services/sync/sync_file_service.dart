library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/sync_adapter.dart';
import 'package:louvorja_piano_mobile/core/services/sync/sync_package.dart';

/// Exporta/importa o pacote `.louvorja` via SAF (Android) / diálogo nativo.
///
/// O file picker é channel (não testável em unit); a lógica pura —
/// nome de arquivo e validação — é estática e testada.
class SyncFileService {
  /// Nome canônico: louvorja-AAAA-MM-DD.louvorja
  static String fileNameFor(DateTime now) {
    final d = now.toIso8601String().substring(0, 10);
    return 'louvorja-$d.louvorja';
  }

  /// Valida que o conteúdo decodifica como SyncPackage válido.
  static bool isValidContent(String raw) {
    try {
      SyncPackage.decode(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Exporta: devolve o caminho escolhido pelo usuário ou null (cancelou).
  Future<String?> export() async {
    final prefs = await SharedPreferences.getInstance();
    final pkg = await SyncAdapter(prefs).export();
    final uri = await FilePicker.saveFile(
      fileName: fileNameFor(DateTime.now()),
      bytes: Uint8List.fromList(utf8.encode(pkg.encode())),
    );
    return uri?.toString();
  }

  /// Importa: escolhe arquivo, valida e aplica com LWW.
  /// Devolve o resultado ou null se cancelou/inválido.
  Future<SyncImportResult?> import() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;

    final raw = utf8.decode(await file.readAsBytes());

    if (!isValidContent(raw)) return null;

    final prefs = await SharedPreferences.getInstance();
    return SyncAdapter(prefs).importPackage(SyncPackage.decode(raw));
  }
}
