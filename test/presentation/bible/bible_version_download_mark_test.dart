import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_download_button.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('bible_mark_test');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });

  tearDownAll(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  test('warmUp resolve _docsDir sem erro', () async {
    BibleVersionDownloadMark.warmUp();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(BibleVersionDownloadMark.isDownloaded(7), isFalse);
  });

  test('isDownloaded false para id desconhecido', () {
    expect(BibleVersionDownloadMark.isDownloaded(1234), isFalse);
  });

  test('markDownloaded grava arquivo e isDownloaded confirma', () async {
    await BibleVersionDownloadMark.markDownloaded(7);

    expect(BibleVersionDownloadMark.isDownloaded(7), isTrue);
    expect(BibleVersionDownloadMark.isDownloaded(8), isFalse);
    expect(
      File(BibleVersionDownloadMark.pathFor(7)).readAsStringSync(),
      contains('7'),
    );
  });
}
