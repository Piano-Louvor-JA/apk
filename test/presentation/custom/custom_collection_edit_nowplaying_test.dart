import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collection_edit_page.dart';

/// SPEC 4 (apk#91): tocar música em coletânea custom precisa registrar a
/// faixa no [NowPlayingNotifier] global — é o que faz o MiniPlayerBar
/// (main_navigation) aparecer em TODAS as abas.
class _FakePlayer implements HymnAudioPlayer {
  final _stream = StreamController<bool>.broadcast();
  bool paused = false;
  bool failPlay = false;
  Completer<void>? pendingPlay;
  int playCalls = 0;
  String? playedUrl;

  @override
  String? get currentUrl => playedUrl;
  @override
  bool get isPlaying => playedUrl != null && !paused;
  @override
  Stream<bool> get playingStream => _stream.stream;
  @override
  Stream<void> get completionStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration> get durationStream => const Stream.empty();
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> pause() async {
    paused = true;
    _stream.add(false);
  }

  @override
  Future<void> resume() async {
    if (playedUrl == null) return;
    paused = false;
    _stream.add(true);
  }

  @override
  Future<void> playUrl(String url) async {
    playCalls++;
    if (pendingPlay != null) await pendingPlay!.future;
    if (failPlay) throw StateError("falha de áudio");
    playedUrl = url;
    paused = false;
    _stream.add(true);
  }

  @override
  Future<void> toggleUrl(String url) async =>
      (currentUrl == url && isPlaying) ? pause() : playUrl(url);
  @override
  Future<void> stop() async {
    playedUrl = null;
    paused = false;
    _stream.add(false);
  }

  @override
  void dispose() => _stream.close();
}

void main() {
  late CustomCatalogApiImpl api;
  late _FakePlayer player;
  bool withTiming = true;

  final collection = const CustomCollection(
    id: 6,
    name: 'Minha Coletânea',
    musicsCount: 1,
    isOwner: true,
  );

  Widget wrap(Widget child) => MaterialApp(home: child);

  setUp(() {
    nowPlaying.stop();
    player = _FakePlayer();
    withTiming = true;
    api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        if (method == 'GET' && url.contains('/collections/6/musics')) {
          return {
            'data': [
              {
                'id_music': 10,
                'id_collection': 6,
                'name': 'Hino A',
                'audio_url': 'audio/hino-a.mp3',
                'duration': '00:02:17',
              },
            ],
          };
        }
        if (method == 'GET' && url.endsWith('/musics/10')) {
          return {
            'id_music': 10,
            'name': 'Hino A',
            'audio_url': 'audio/hino-a.mp3',
            'duration': '00:02:17',
            'lyrics': withTiming
                ? [
                    {
                      'lyric': 'Verso',
                      'time': '00:00:01.000',
                      'order': 1,
                      'image_url': null,
                    },
                  ]
                : [],
          };
        }
        return <String, dynamic>{};
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );
  });

  testWidgets('play custom registra faixa no now playing global', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CustomCollectionEditPage(
          api: api,
          collection: collection,
          bearerToken: 'tok',
          audioPlayer: player,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hino A'));
    await tester.pumpAndSettle();

    expect(player.playedUrl, 'https://api.test/file/audio/hino-a.mp3');
    expect(nowPlaying.hasTrack, isTrue);
    expect(nowPlaying.track?.hymnId, CustomCatalogApiImpl.customIdOffset + 10);
    expect(nowPlaying.track?.title, 'Hino A');
    expect(nowPlaying.isPlaying, isTrue);
  });
  Future<void> showCollection(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        CustomCollectionEditPage(
          api: api,
          collection: collection,
          bearerToken: 'tok',
          audioPlayer: player,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void seedTrack() {
    nowPlaying.start(
      hymnId: 99,
      title: 'Faixa anterior',
      album: 'Hinário',
      audioSource: 'https://example.com/old.mp3',
    );
    player.playedUrl = 'https://example.com/old.mp3';
  }

  testWidgets('slides sem fonte não substituem a faixa global em execução', (
    tester,
  ) async {
    withTiming = false;
    seedTrack();
    await showCollection(tester);
    await tester.tap(find.text('Hino A'));
    await tester.pumpAndSettle();
    expect(player.playCalls, 0);
    expect(nowPlaying.track?.hymnId, 99);
    expect(nowPlaying.track?.audioSource, player.currentUrl);
  });

  testWidgets('falha de áudio mantém a faixa global anterior', (tester) async {
    player.failPlay = true;
    seedTrack();
    await showCollection(tester);
    await tester.tap(find.text('Hino A'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(nowPlaying.track?.hymnId, 99);
    expect(nowPlaying.track?.audioSource, player.currentUrl);
  });

  testWidgets('toques repetidos não iniciam duas reproduções', (tester) async {
    player.pendingPlay = Completer<void>();
    await showCollection(tester);
    await tester.tap(find.text('Hino A'));
    await tester.pump();
    await tester.tap(find.text('Hino A'));
    await tester.pump();
    expect(player.playCalls, 1);
    player.pendingPlay!.complete();
    await tester.pumpAndSettle();
    expect(nowPlaying.track?.hymnId, CustomCatalogApiImpl.customIdOffset + 10);
  });
}
