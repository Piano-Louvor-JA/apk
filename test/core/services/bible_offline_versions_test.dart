import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bible_offline_versions.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
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
  const versions = [
    BibleVersion(id: 1, abbreviation: 'ARA', name: 'Almeida'),
    BibleVersion(id: 2, abbreviation: 'NVI', name: 'Nova Versão'),
  ];

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('bible_versions_test');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    BibleOfflineVersions.invalidate();
  });

  tearDown(() async => docs.delete(recursive: true));

  test('primeiro filtro mantém catálogo inteiro enquanto aquece cache', () {
    expect(BibleOfflineVersions.filter(versions), same(versions));
  });

  test('cache invalidado mantém catálogo inteiro até novo veredito', () async {
    BibleOfflineVersions.filter(versions);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    BibleOfflineVersions.invalidate();

    expect(BibleOfflineVersions.filter(versions), same(versions));
  });
}
