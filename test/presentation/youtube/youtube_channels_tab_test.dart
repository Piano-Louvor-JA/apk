import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_channels.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
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

const arautosId = 'UCaaaaaaaaaaaaaaaaaaaaaa';

YoutubeVideo hymn(int n, [String name = 'Hino']) => YoutubeVideo(
  videoId: 'hino${'$n'.padLeft(7, '0')}',
  title: 'Novo Hinário Adventista • Hino $n • $name $n • (Lyrics)',
  channel: 'Casa Publicadora Brasileira',
);

YoutubeChannelResult arautos([List<String> names = const ['Hinos de Natal', 'Louvores Antigos']]) =>
    YoutubeChannelResult(
      channel: const YoutubeChannelInfo(
        id: arautosId,
        name: 'Arautos do Rei',
        url: 'https://www.youtube.com/@arautos',
      ),
      playlists: [
        for (var i = 0; i < names.length; i++)
          YoutubeChannelPlaylistInfo(id: 'PLarautos00000$i', title: names[i], videoCount: 10 + i),
      ],
    );

class _Search implements YoutubeSearchRepository {
  final playlistCalls = <String>[];
  final channelCalls = <String>[];
  final channelQueries = <String>[];
  Future<YoutubePlaylistResult> Function(String id) onPlaylist = (id) async {
    final i = cpbChannel.playlists.indexWhere((p) => p.id == id);
    if (i < 0) {
      return YoutubePlaylistResult(
        title: id,
        items: [YoutubeVideo(videoId: 'arautos${id.substring(id.length - 4)}', title: 'Castelo Forte', channel: 'Arautos do Rei')],
      );
    }
    return YoutubePlaylistResult(items: [hymn(i * 100 + 1, 'Abertura'), hymn(i * 100 + 2, 'Graça')]);
  };
  YoutubeChannelResult Function(String text) onChannel = (_) => arautos();
  YoutubeChannelSearchResult Function(String query) onSearchChannels = (_) =>
      const YoutubeChannelSearchResult(items: [
        YoutubeChannelSearchItem(id: arautosId, name: 'Arautos do Rei', url: 'https://www.youtube.com/channel/$arautosId', handle: '@arautos', subscribers: '12 mil inscritos'),
        YoutubeChannelSearchItem(id: 'UCQhkLOO40bmTMeLcbspKW8A', name: 'Casa Publicadora Brasileira', url: 'https://www.youtube.com/channel/UCQhkLOO40bmTMeLcbspKW8A'),
      ]);

  @override
  Future<YoutubeSearchResult> search(String query) async => const YoutubeSearchResult();
  @override
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation) async => const YoutubeSearchResult();
  @override
  Future<YoutubePlaylistResult> playlist(String text) {
    playlistCalls.add(text);
    return onPlaylist(text);
  }

  @override
  Future<YoutubeChannelResult> channel(String text) async {
    channelCalls.add(text);
    return onChannel(text);
  }

  @override
  Future<YoutubeChannelSearchResult> searchChannels(String query) async {
    channelQueries.add(query);
    return onSearchChannels(query);
  }
}

Future<void> _pump(WidgetTester tester, _Search search) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
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
            openPlayer: (_, _) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('youtube-tab-channels')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('youtube-tab-channels')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('youtube-channels-list')), findsOneWidget);
}

Finder _title(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.key == const Key('youtube-channel-title') && w.data == text,
);

void main() {
  testWidgets('a CPB vem no app e abre todos os hinos numa lista só, com busca pelo número', (tester) async {
    final search = _Search();
    await _pump(tester, search);
    expect(find.text('Casa Publicadora Brasileira'), findsOneWidget);
    expect(find.text('Novo Hinário Adventista'), findsOneWidget);

    await tester.tap(find.byKey(const Key('youtube-channel-cpb')));
    await tester.pumpAndSettle();
    expect(search.playlistCalls, hasLength(6));
    expect(_title('Casa Publicadora Brasileira'), findsOneWidget);
    expect(find.text('12 vídeo(s)'), findsOneWidget);
    expect(find.byKey(const Key('youtube-channel-save-collection')), findsNothing);

    await tester.enterText(find.byKey(const Key('youtube-channel-filter')), '2');
    await tester.pump();
    expect(find.textContaining('Graça 2 '), findsOneWidget);
    expect(find.textContaining('Hino 102'), findsNothing);

    await tester.enterText(find.byKey(const Key('youtube-channel-filter')), '999');
    await tester.pump();
    expect(find.byKey(const Key('youtube-channel-no-match')), findsOneWidget);

    await tester.tap(find.byKey(const Key('youtube-channel-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-channel-cpb')), findsOneWidget);
  });

  testWidgets('falha ao carregar mostra erro; "Tentar de novo" completa a lista', (tester) async {
    final search = _Search();
    var calls = 0;
    final normal = search.onPlaylist;
    search.onPlaylist = (id) {
      calls++;
      return calls == 3 ? Future.value(const YoutubePlaylistResult(error: 'network')) : normal(id);
    };
    await _pump(tester, search);
    await tester.tap(find.byKey(const Key('youtube-channel-cpb')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-channel-error')), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('12 vídeo(s)'), findsOneWidget);
  });

  testWidgets('cadastrar pelo link abre nas playlists; a playlist abre os vídeos e vira coletânea', (tester) async {
    final search = _Search();
    await _pump(tester, search);
    await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), 'a');
    await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), 'ar');
    await tester.tap(find.byKey(const Key('youtube-channel-add')));
    await tester.pumpAndSettle();
    // cadastra e, ao abrir, relê o canal pelo link salvo
    expect(search.channelCalls, ['ar', 'https://www.youtube.com/@arautos']);
    expect(_title('Arautos do Rei'), findsOneWidget);
    expect(find.text('Hinos de Natal'), findsOneWidget);
    expect(find.text('Louvores Antigos'), findsOneWidget);
    expect(find.text('10 vídeo(s)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('youtube-channel-playlist-filter')), 'natal');
    await tester.pump();
    expect(find.text('Louvores Antigos'), findsNothing);
    await tester.enterText(find.byKey(const Key('youtube-channel-playlist-filter')), '');
    await tester.pump();

    await tester.tap(find.text('Louvores Antigos'));
    await tester.pumpAndSettle();
    expect(search.playlistCalls.single, 'PLarautos000001');
    expect(_title('Louvores Antigos'), findsOneWidget);
    expect(find.text('Castelo Forte'), findsOneWidget);

    await tester.tap(find.byKey(const Key('youtube-channel-save-collection')));
    await tester.pumpAndSettle();
    expect((await YoutubeLibraryStorage().collections()).single.name, 'Louvores Antigos');

    // salvo no aparelho
    expect((await YoutubeLibraryStorage().channels()).map((c) => c.id), ['cpb', arautosId]);
  });

  testWidgets('colar um link de canal cadastra na hora; erro mostra o aviso', (tester) async {
    final search = _Search();
    search.onChannel = (_) => const YoutubeChannelResult(error: 'invalid');
    await _pump(tester, search);
    await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), 'https://www.youtube.com/@arautos');
    await tester.pumpAndSettle();
    expect(search.channelCalls.single, 'https://www.youtube.com/@arautos');
    expect(find.byKey(const Key('youtube-channel-add-error')), findsOneWidget);
    expect(find.textContaining('não é de um canal'), findsOneWidget);

    // digitar letra por letra não cadastra sozinho
    await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), '');
    for (final text in ['@', '@a', '@ar', '@ara']) {
      await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), text);
    }
    await tester.pumpAndSettle();
    expect(search.channelCalls, hasLength(1));
  });

  testWidgets('pesquisa canais adventistas enquanto digita e cadastra pelo resultado', (tester) async {
    final search = _Search();
    await _pump(tester, search);
    await tester.enterText(find.byKey(const Key('youtube-channel-search-input')), 'lo');
    await tester.pump(const Duration(milliseconds: 800));
    expect(search.channelQueries, isEmpty);

    await tester.enterText(find.byKey(const Key('youtube-channel-search-input')), 'louvor');
    await tester.pump(const Duration(milliseconds: 600));
    expect(search.channelQueries, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(search.channelQueries, ['louvor']);
    expect(find.byKey(const Key('youtube-channel-results')), findsOneWidget);
    expect(find.textContaining('@arautos · 12 mil inscritos'), findsOneWidget);
    expect(find.byKey(const Key('youtube-channel-result-open-UCQhkLOO40bmTMeLcbspKW8A')), findsOneWidget);

    await tester.tap(find.byKey(const Key('youtube-channel-result-add-$arautosId')));
    await tester.pumpAndSettle();
    expect(search.channelCalls.first, 'https://www.youtube.com/channel/$arautosId');
    expect(_title('Arautos do Rei'), findsOneWidget);

    await tester.tap(find.byKey(const Key('youtube-channel-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-channel-result-open-$arautosId')), findsOneWidget);

    // apagar fecha a pesquisa
    await tester.enterText(find.byKey(const Key('youtube-channel-search-input')), '');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-channel-results')), findsNothing);
  });

  testWidgets('excluir canal cadastrado pede confirmação; a CPB não tem excluir', (tester) async {
    final search = _Search();
    await _pump(tester, search);
    expect(find.byKey(const Key('youtube-channel-delete-cpb')), findsNothing);
    await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), 'x');
    await tester.enterText(find.byKey(const Key('youtube-channel-add-input')), 'xy');
    await tester.tap(find.byKey(const Key('youtube-channel-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('youtube-channel-delete-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('youtube-channel-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-channel-$arautosId')), findsNothing);
    expect(await YoutubeLibraryStorage().channels(), hasLength(1));
  });

  testWidgets('colar link de playlist em "Colar playlist" lê sozinho', (tester) async {
    final search = _Search();
    final pasted = <String>[];
    search.onPlaylist = (id) async {
      pasted.add(id);
      return const YoutubePlaylistResult(title: 'Natal', items: [YoutubeVideo(videoId: 'AAAAAAAAAAA', title: 'Um')]);
    };
    await _pump(tester, search);
    await tester.tap(find.byKey(const Key('youtube-playlist-import')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('youtube-playlist-url')), 'https://www.youtube.com/playlist?list=PLVk-tYq6iIlM');
    await tester.pumpAndSettle();
    expect(pasted, ['https://www.youtube.com/playlist?list=PLVk-tYq6iIlM']);
    expect(find.byKey(const Key('youtube-playlist-name')), findsOneWidget);
  });
}
