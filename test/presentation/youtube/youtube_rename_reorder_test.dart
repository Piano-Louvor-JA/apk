import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_link_info.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/liturgy_link_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/widgets/youtube_reorder.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/widgets/youtube_video_tile.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/youtube_page.dart';

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

class _Search implements YoutubeSearchRepository {
  @override
  Future<YoutubeSearchResult> search(String query) async =>
      const YoutubeSearchResult();
  @override
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation) async =>
      const YoutubeSearchResult();
  @override
  Future<YoutubePlaylistResult> playlist(String text) async =>
      const YoutubePlaylistResult(error: 'invalid');
}

const v1 = YoutubeVideo(
  videoId: 'AAAAAAAAAAA',
  title: 'Arautos do Rei | 60 Anos',
);

Widget _app(Widget home) => EasyLocalization(
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
      home: home,
    ),
  ),
);

Future<void> _io(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => YoutubeDownloads.supportedOverride = null);

  testWidgets(
    'baixado: lixeira, ✓ e renomear, com prévia do nome e o nome guardado',
    (tester) async {
      YoutubeDownloads.supportedOverride = true;
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('yt-rename'),
      );
      final downloads = YoutubeDownloads(
        cache: () async => LiturgyVideoCache(dir!, _Remote()),
      );
      await tester.runAsync(() async {
        downloads.download([v1]);
        for (var i = 0; i < 100 && downloads.hasPending; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: YoutubeDownloadButton(video: v1, downloads: downloads),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ordem do desktop: lixeira, ✓, renomear.
      final trash = tester.getCenter(
        find.byKey(const Key('youtube-download-remove-AAAAAAAAAAA')),
      );
      final check = tester.getCenter(
        find.byKey(const Key('youtube-download-AAAAAAAAAAA')),
      );
      final rename = tester.getCenter(
        find.byKey(const Key('youtube-download-rename-AAAAAAAAAAA')),
      );
      expect(trash.dx < check.dx && check.dx < rename.dx, isTrue);

      await tester.tap(
        find.byKey(const Key('youtube-download-rename-AAAAAAAAAAA')),
      );
      await _io(tester);
      final field = find.byKey(const Key('youtube-rename-field'));
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Arautos do Rei 60 Anos',
      );

      // Sem mudança: só fecha.
      await tester.tap(find.byKey(const Key('youtube-rename-confirm')));
      await _io(tester);
      expect(field, findsNothing);
      expect(downloads.downloaded.single.renamed, isFalse);

      await tester.tap(
        find.byKey(const Key('youtube-download-rename-AAAAAAAAAAA')),
      );
      await _io(tester);
      await tester.enterText(field, 'Abertura — sábado / 19h!');
      await tester.pump();
      expect(find.text('Abertura sabado 19h_AAAAAAAAAAA.mp4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('youtube-rename-confirm')));
      await _io(tester);
      expect(downloads.downloaded.single.renamed, isTrue);
      expect(downloads.fileNameOf(v1), 'Abertura sabado 19h_AAAAAAAAAAA.mp4');
      expect(
        find.text('Arquivo renomeado: Abertura sabado 19h_AAAAAAAAAAA.mp4'),
        findsOneWidget,
      );

      // Cancelar não muda nada.
      await tester.tap(
        find.byKey(const Key('youtube-download-rename-AAAAAAAAAAA')),
      );
      await _io(tester);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Abertura sabado 19h',
      );
      await tester.tap(find.text('Cancelar'));
      await _io(tester);
      expect(downloads.fileNameOf(v1), 'Abertura sabado 19h_AAAAAAAAAAA.mp4');

      await tester.runAsync(() => dir!.delete(recursive: true));
    },
  );

  testWidgets('linha renomeada mostra o nome do arquivo em destaque', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: YoutubeVideoTile(
            video: v1,
            favorite: false,
            onPlay: () {},
            onFavorite: () {},
            onAddToCollection: () {},
            subtitle: '2 KB',
            detail: 'Arquivo renomeado: X_AAAAAAAAAAA.mp4',
            leading: const YoutubeGrip(hint: 'arraste'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-detail-AAAAAAAAAAA')), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
  });

  testWidgets(
    'histórico: tocar e segurar arrasta a linha (destacada) e a ordem fica salva',
    (tester) async {
      YoutubeDownloads.supportedOverride = false;
      var now = 1;
      final storage = YoutubeLibraryStorage(clock: () => now++);
      await storage.recordPlay(
        const YoutubeVideo(videoId: 'AAAAAAAAAAA', title: 'Primeiro'),
      );
      await storage.recordPlay(
        const YoutubeVideo(videoId: 'BBBBBBBBBBB', title: 'Segundo'),
      );
      await storage.recordPlay(
        const YoutubeVideo(videoId: 'CCCCCCCCCCC', title: 'Terceiro'),
      );
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          YoutubePage(
            search: _Search(),
            storage: storage,
            openPlayer: (_, _) async {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.byType(YoutubeGrip), findsNWidgets(3));

      // Terceiro (topo) para depois do Primeiro (fim).
      final from = tester.getCenter(find.text('Terceiro'));
      final to = tester.getCenter(find.text('Primeiro'));
      final gesture = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(find.byKey(const Key('youtube-dragging')), findsOneWidget);
      // Desce em passos até passar do último (o ReorderableListView anima).
      final target = to + const Offset(0, 120);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect((await YoutubeLibraryStorage().history()).map((e) => e.title), [
        'Segundo',
        'Primeiro',
        'Terceiro',
      ]);
    },
  );

  testWidgets(
    'Baixados: botão ao lado do espaço abre a lista no lugar das abas e volta',
    (tester) async {
      YoutubeDownloads.supportedOverride = true;
      await tester.pumpWidget(
        _app(
          YoutubePage(
            search: _Search(),
            storage: YoutubeLibraryStorage(),
            openPlayer: (_, _) async {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Não é aba: fica na barra, à direita do espaço usado.
      expect(find.widgetWithText(Tab, 'Baixados'), findsNothing);
      final storage = tester.getCenter(
        find.byKey(const Key('youtube-storage')),
      );
      final button = tester.getCenter(
        find.byKey(const Key('youtube-downloads-open')),
      );
      expect(button.dx > storage.dx, isTrue);

      await tester.tap(find.byKey(const Key('youtube-downloads-open')));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.text(
          'Nenhum vídeo baixado ainda. Use o botão de download nos vídeos para tocar sem internet.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('youtube-downloads-back')));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);

      // Tocar de novo no botão também fecha; o voltar do sistema também.
      await tester.tap(find.byKey(const Key('youtube-downloads-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('youtube-downloads-open')));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      await tester.tap(find.byKey(const Key('youtube-downloads-open')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
    },
  );
}
