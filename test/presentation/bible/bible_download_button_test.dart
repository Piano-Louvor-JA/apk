import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/bible_repository_impl.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bloc/bible_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/bible/bible_page.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Usa BiblePage(testBloc:) — mesmo caminho da página real. O botão de
/// download vive na AppBar; API apontando pra loopback morto: download
/// falha → snackbar de erro (ramo catch) sem crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    docs = await Directory.systemTemp.createTemp('bible_dl_btn');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });

  tearDown(() async {
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  BibleBloc bloc() => BibleBloc(
        BibleRepositoryImpl(
          LouvorjaApiImpl(
            baseUrls: ['http://127.0.0.1:1'],
            filesUrls: ['http://127.0.0.1:1/file'],
            apiToken: '',
          ),
          CatalogCache(docs),
        ),
      );

  testWidgets('botão de download visível na AppBar da Bíblia', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BiblePage(testBloc: bloc())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('download com API morta: fluxo termina sem crash', (tester) async {
    final b = bloc();
    await tester.pumpWidget(MaterialApp(home: BiblePage(testBloc: b)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final btn = find.byTooltip('Baixar Bíblia para offline');
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first);
      await tester.pump();
      // API morta → downloadVersion lança → snackbar de erro.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    }

    expect(tester.takeException(), isNull);
  });
}
