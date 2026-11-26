import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_youtube_library.dart';
import 'package:louvorja_piano_mobile/core/services/youtube/youtube_downloads.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_remote_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';
import 'package:louvorja_piano_mobile/domain/repositories/youtube_search_repository.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';
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
  @override
  Future<YoutubeSearchResult> search(String query) async =>
      const YoutubeSearchResult(
        items: [
          YoutubeVideo(
            videoId: 'AAAAAAAAAAA',
            title: 'Castelo Forte',
            channel: 'Arautos do Rei',
          ),
        ],
      );
  @override
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation) async =>
      const YoutubeSearchResult();
  @override
  Future<YoutubePlaylistResult> playlist(String text) async =>
      const YoutubePlaylistResult(error: 'invalid');
  @override
  Future<YoutubeChannelResult> channel(String text) async =>
      const YoutubeChannelResult(error: 'invalid');
  @override
  Future<YoutubeChannelSearchResult> searchChannels(String query) async =>
      const YoutubeChannelSearchResult(error: 'empty');
}

extension on RemotePlayerState {
  RemotePlayerState copyWithLibrary({List<Object?>? history, String key = 'k1'}) => RemotePlayerState(
    playing: playing,
    position: position,
    duration: duration,
    slideIndex: slideIndex,
    slideCount: slideCount,
    volume: volume,
    canPrevious: canPrevious,
    canNext: canNext,
    youtubeLibraryKey: key,
    youtubeHistory: history,
    youtubeFavorites: const [],
  );
}

RemotePlayerState remoteState({String? title}) => RemotePlayerState(
  title: title,
  playing: title != null,
  position: Duration.zero,
  duration: title == null ? Duration.zero : const Duration(minutes: 3),
  slideIndex: 0,
  slideCount: 0,
  volume: 80,
  canPrevious: false,
  canNext: false,
);

Future<void> _pump(
  WidgetTester tester, {
  required YoutubePlayerOpener openPlayer,
  Stream<RemotePlayerState>? states,
  RemotePlayerState? initial,
  YoutubeLibraryStorage? storage,
}) async {
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
            search: _Search(),
            storage: storage ?? YoutubeLibraryStorage(),
            openPlayer: openPlayer,
            remote: true,
            remoteStates: states ?? const Stream.empty(),
            remoteInitialState: initial,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('youtube-search-field')),
    'castelo forte',
  );
  await tester.tap(find.byKey(const Key('youtube-search-submit')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => YoutubeDownloads.supportedOverride = null);

  testWidgets(
    'no controle remoto, tocar manda o vídeo para o computador e não há downloads do celular',
    (tester) async {
      YoutubeDownloads.supportedOverride = true;
      final opened = <YoutubeVideo>[];
      await _pump(tester, openPlayer: (_, video) async => opened.add(video));
      expect(find.text('Toca no computador'), findsOneWidget);
      expect(find.byKey(const Key('youtube-downloads-open')), findsNothing);
      expect(find.byKey(const Key('youtube-storage')), findsNothing);

      await _search(tester);
      expect(
        find.byKey(const Key('youtube-download-AAAAAAAAAAA')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('youtube-play-AAAAAAAAAAA')));
      await tester.pumpAndSettle();
      expect(opened.single.title, 'Castelo Forte');
    },
  );

  testWidgets(
    'a barra do player do computador (a mesma da liturgia) aparece com mídia aberta',
    (tester) async {
      final states = StreamController<RemotePlayerState>.broadcast();
      addTearDown(states.close);
      await _pump(
        tester,
        openPlayer: (_, _) async {},
        states: states.stream,
        initial: remoteState(),
      );
      expect(find.byType(RemotePlayerBar), findsNothing);

      states.add(remoteState(title: 'Castelo Forte'));
      await tester.pumpAndSettle();
      expect(find.byType(RemotePlayerBar), findsOneWidget);
      expect(find.text('Castelo Forte'), findsWidgets);

      states.add(remoteState());
      await tester.pumpAndSettle();
      expect(find.byType(RemotePlayerBar), findsNothing);
    },
  );

  testWidgets(
    'youtubeDesktopOpener envia youtube.play com link, título e canal',
    (tester) async {
      final sent = <RemoteCommand>[];
      var connected = true;
      final opener = youtubeDesktopOpener(
        send: (command) async => sent.add(command),
        connected: () => connected,
      );
      await _pump(tester, openPlayer: opener);
      await _search(tester);
      await tester.tap(find.byKey(const Key('youtube-play-AAAAAAAAAAA')));
      await tester.pumpAndSettle();
      final command = sent.single;
      expect(command.action, RemoteAction.youtubePlay);
      expect(command.url, 'https://www.youtube.com/watch?v=AAAAAAAAAAA');
      expect(command.name, 'Castelo Forte');
      expect(command.channel, 'Arautos do Rei');
      expect(find.textContaining('Abrindo no computador'), findsOneWidget);

      // desconectado: avisa e não envia
      connected = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('youtube-play-AAAAAAAAAAA')));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
    },
  );

  testWidgets('no controle remoto, o histórico é o do computador e acompanha as mudanças', (tester) async {
    RemoteYoutubeLibrary.reset();
    Map<String, dynamic> entry(String id, String title) => {'videoId': id, 'title': title, 'playedAt': 1};
    RemoteYoutubeLibrary.remember(
      remoteState().copyWithLibrary(history: [entry('AAAAAAAAAAA', 'Deus o Pode')]),
    );
    await _pump(
      tester,
      openPlayer: (_, _) async {},
      storage: YoutubeRemoteLibraryStorage(send: (_) async {}),
    );
    await tester.tap(find.textContaining('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Deus o Pode'), findsOneWidget);

    RemoteYoutubeLibrary.remember(
      remoteState().copyWithLibrary(history: [entry('BBBBBBBBBBB', 'Castelo Forte')], key: 'k2'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Castelo Forte'), findsOneWidget);
    expect(find.text('Deus o Pode'), findsNothing);
  });
}
