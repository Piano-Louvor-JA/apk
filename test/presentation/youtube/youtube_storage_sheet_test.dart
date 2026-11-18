import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/liturgy_link_repository.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/widgets/youtube_sheets.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      (jsonDecode(File('assets/translations/pt-BR.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>();
}

class _Remote implements LiturgyLinkRepository {
  @override
  Future<LiturgyLinkInfo> info(String url) async =>
      const LiturgyLinkInfo(title: 'x');

  @override
  Future<void> download(
    String url,
    String destination, {
    void Function(int, int)? onProgress,
  }) async {
    await File(destination).writeAsBytes(List.filled(2048, 1));
    onProgress?.call(2048, 2048);
  }
}

const v1 = YoutubeVideo(videoId: 'AAAAAAAAAAA', title: 'Meu Pastor');
const v2 = YoutubeVideo(videoId: 'BBBBBBBBBBB', title: 'Vox - Hino 2');
const v3 = YoutubeVideo(videoId: 'CCCCCCCCCCC', title: 'Não baixado');

/// Deixa o disco (tempo real) e a tela andarem algumas vezes.
Future<void> _io(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista os baixados com lixeira e apaga um ou todos', (
    tester,
  ) async {
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('yt-storage'),
    );
    final downloads = YoutubeDownloads(
      cache: () async => LiturgyVideoCache(dir!, _Remote()),
    );
    await tester.runAsync(() async {
      downloads.download([v1, v2]);
      for (var i = 0; i < 100 && downloads.hasPending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(downloads.totalVideos, 2);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('pt', 'BR')],
        path: 'assets/translations',
        assetLoader: const _Translations(),
        startLocale: const Locale('pt', 'BR'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showYoutubeStorageSheet(
                    context,
                    known: const [v1, v2, v3],
                    downloads: downloads,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await _io(tester);

    expect(find.text('Meu Pastor'), findsOneWidget);
    expect(find.text('Vox - Hino 2'), findsOneWidget);
    expect(find.text('Não baixado'), findsNothing);

    // Lixeira de um vídeo.
    await tester.tap(
      find.byKey(const Key('youtube-storage-remove-AAAAAAAAAAA')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('youtube-storage-remove-confirm')));
    await _io(tester);
    expect(find.text('Meu Pastor'), findsNothing);
    expect(downloads.totalVideos, 1);

    // Com um só, não há "Apagar todos"; a lixeira dele basta.
    expect(find.byKey(const Key('youtube-storage-remove-all')), findsNothing);
    await tester.tap(
      find.byKey(const Key('youtube-storage-remove-BBBBBBBBBBB')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('youtube-storage-remove-confirm')));
    await _io(tester);
    expect(find.text('Nenhum vídeo do YouTube baixado.'), findsOneWidget);
    expect(downloads.totalVideos, 0);

    await tester.runAsync(() => dir!.delete(recursive: true));
  });

  testWidgets('"Apagar todos" apaga todos os baixados', (tester) async {
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('yt-storage'),
    );
    final downloads = YoutubeDownloads(
      cache: () async => LiturgyVideoCache(dir!, _Remote()),
    );
    await tester.runAsync(() async {
      downloads.download([v1, v2]);
      for (var i = 0; i < 100 && downloads.hasPending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('pt', 'BR')],
        path: 'assets/translations',
        assetLoader: const _Translations(),
        startLocale: const Locale('pt', 'BR'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showYoutubeStorageSheet(
                    context,
                    known: const [v1, v2],
                    downloads: downloads,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await _io(tester);
    await tester.tap(find.byKey(const Key('youtube-storage-remove-all')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('youtube-storage-remove-all-confirm')),
    );
    await _io(tester);
    expect(downloads.totalVideos, 0);
    expect(find.text('Nenhum vídeo do YouTube baixado.'), findsOneWidget);
    await tester.runAsync(() => dir!.delete(recursive: true));
  });
}
