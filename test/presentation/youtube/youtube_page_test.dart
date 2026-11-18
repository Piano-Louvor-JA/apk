import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';
import 'package:louvorja_piano_mobile/presentation/youtube/youtube_page.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      (jsonDecode(File('assets/translations/pt-BR.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>();
}

class _Search implements YoutubeSearchRepository {
  final queries = <String>[];
  @override
  Future<YoutubeSearchResult> search(String query) async {
    queries.add(query);
    return const YoutubeSearchResult(
      items: [
        YoutubeVideo(
          videoId: 'AAAAAAAAAAA',
          title: 'Meu Pastor',
          channel: 'Arautos do Rei',
          durationText: '4:12',
        ),
        YoutubeVideo(videoId: 'BBBBBBBBBBB', title: 'Vox - Hino 2'),
      ],
    );
  }

  @override
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation) async =>
      const YoutubeSearchResult();

  @override
  Future<YoutubePlaylistResult> playlist(String text) async =>
      const YoutubePlaylistResult(error: 'invalid');
}

Future<void> _pumpPage(
  WidgetTester tester,
  _Search search, {
  List<String>? played,
}) async {
  SharedPreferences.setMockInitialValues({});
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
          home: YoutubePage(
            search: search,
            storage: YoutubeLibraryStorage(),
            openPlayer: (_, video) async => played?.add(video.videoId),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => YoutubeDownloads.supportedOverride = null);

  testWidgets('busca, toca (vai para o histórico), favorita e cria coletânea', (
    tester,
  ) async {
    final search = _Search();
    final played = <String>[];
    await _pumpPage(tester, search, played: played);

    expect(
      find.text('Digite o nome de um hino, cantor ou coral para buscar.'),
      findsOneWidget,
    );

    // Digitar já busca sozinho depois da pausa.
    await tester.enterText(
      find.byKey(const Key('youtube-search-field')),
      'adoradores',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(search.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(search.queries, ['adoradores']);

    // Lupa busca na hora.
    await tester.enterText(
      find.byKey(const Key('youtube-search-field')),
      'arautos do rei',
    );
    await tester.tap(find.byKey(const Key('youtube-search-submit')));
    await tester.pumpAndSettle();
    expect(search.queries, ['adoradores', 'arautos do rei']);
    expect(find.text('Meu Pastor'), findsOneWidget);

    expect(find.byKey(const Key('youtube-project-AAAAAAAAAAA')), findsNothing);
    await tester.tap(find.byKey(const Key('youtube-play-AAAAAAAAAAA')));
    await tester.pumpAndSettle();
    expect(played, ['AAAAAAAAAAA']);

    await tester.tap(find.byKey(const Key('youtube-favorite-AAAAAAAAAAA')));
    await tester.pumpAndSettle();
    expect(
      (await YoutubeLibraryStorage().favorites()).single.videoId,
      'AAAAAAAAAAA',
    );

    // Histórico (aba com o contador).
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('1× tocado'), findsOneWidget);

    // Coletâneas: cria uma.
    await tester.tap(find.text('Coletâneas'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('youtube-collection-new')),
      'Culto Jovem',
    );
    await tester.tap(find.byKey(const Key('youtube-collection-create')));
    await tester.pumpAndSettle();
    expect(find.text('Culto Jovem'), findsOneWidget);
    expect(
      (await YoutubeLibraryStorage().collections()).single.name,
      'Culto Jovem',
    );
  });

  testWidgets('no iOS não mostra download (só toca online)', (tester) async {
    YoutubeDownloads.supportedOverride = false;
    await _pumpPage(tester, _Search());
    await tester.enterText(
      find.byKey(const Key('youtube-search-field')),
      'arautos do rei',
    );
    await tester.tap(find.byKey(const Key('youtube-search-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-play-AAAAAAAAAAA')), findsOneWidget);
    expect(find.byKey(const Key('youtube-download-AAAAAAAAAAA')), findsNothing);
  });

  testWidgets('no Android mostra o botão de download', (tester) async {
    YoutubeDownloads.supportedOverride = true;
    await _pumpPage(tester, _Search());
    await tester.enterText(
      find.byKey(const Key('youtube-search-field')),
      'arautos do rei',
    );
    await tester.tap(find.byKey(const Key('youtube-search-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('youtube-download-AAAAAAAAAAA')),
      findsOneWidget,
    );
  });
}
