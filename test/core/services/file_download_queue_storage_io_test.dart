import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/file_download_queue_storage_io.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory docs;
  late FileDownloadQueueStorage storage;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('dlq_io_test');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    storage = FileDownloadQueueStorage();
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  test('read sem arquivo devolve {} (fila vazia)', () async {
    expect(await storage.read(), '{}');
  });

  test('write persiste e read devolve o mesmo JSON (round-trip)', () async {
    await storage.write('{"1":{"status":"done"}}');

    final raw = await File(
      '${docs.path}/download_queue.json',
    ).readAsString();
    expect(raw, '{"1":{"status":"done"}}');
    expect(await storage.read(), '{"1":{"status":"done"}}');
  });

  test('storage reusa o mesmo File (idempotente)', () async {
    await storage.write('a');
    await storage.write('b');
    expect(await storage.read(), 'b');
  });
}
