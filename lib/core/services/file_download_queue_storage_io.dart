// coverage:ignore-file Necessita filesystem nativo.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'download_queue.dart';

/// Armazenamento da fila de downloads em arquivo JSON no diretorio
/// privado do app. Sobrevive ao fechamento do processo.
class FileDownloadQueueStorage implements DownloadQueueStorage {
  File? _file;

  Future<File> _fileFor() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/download_queue.json');
    return _file!;
  }

  @override
  Future<String> read() async {
    final file = await _fileFor();
    if (!await file.exists()) return '{}';
    return file.readAsString();
  }

  @override
  Future<void> write(String json) async {
    final file = await _fileFor();
    await file.writeAsString(json, flush: true);
  }
}

DownloadQueueStorage createDownloadQueueStorage() => FileDownloadQueueStorage();
