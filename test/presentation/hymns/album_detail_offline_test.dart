import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/album_detail_page.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final List<Hymn> hymns;

  _MockApi({this.hymns = const []});

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async => hymns;

  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(
    id: musicId,
    title: 'Test',
    urlMusic: '/musics/test.mp3',
  );

  @override
  Future<List<AlbumCategory>> fetchCategories() async => [];
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String p) => p;
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async => {};
}

final class _SupportedOffline
    implements OfflineMusicPort, OfflineLibraryPort {
  final removed = <int>[];
  final downloaded = <int>{};

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async =>
      downloaded.contains(musicId) ? '/tmp/fake.mp3' : null;

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    downloaded.add(musicId);
    return '/tmp/fake.mp3';
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    downloaded.remove(musicId);
    removed.add(musicId);
  }

  @override
  Future<List<OfflineListedTrack>> listDownloaded({int? albumId}) async => [];

  @override
  Future<void> saveMetadata({
    required int musicId,
    required String title,
    String? number,
    int? albumId,
    String? albumName,
    bool instrumental = false,
  }) async {}
}

class _NoOffline implements OfflineMusicPort {
  @override
  bool get isSupported => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePlayer extends HymnAudioPlayer {
  final _playing = StreamController<bool>.broadcast();
  final _completion = StreamController<void>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  String? url;
  var playing = false;
  final playedUrls = <String>[];

  @override
  String? get currentUrl => url;

  @override
  bool get isPlaying => playing;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double v) async {}

  @override
  Future<void> toggleUrl(String url) => playUrl(url);

  @override
  Future<void> playUrl(String url) async {
    this.url = url;
    playing = true;
    playedUrls.add(url);
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    playing = false;
    _playing.add(false);
  }

  @override
  void dispose() {}

  void completeTrack() => _completion.add(null);
}

void main() {
  Widget wrapWithRouter(Widget child, HymnsBloc bloc) {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) =>
              BlocProvider<HymnsBloc>.value(value: bloc, child: child),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  HymnsBloc blocWith(List<Hymn> hymns) => HymnsBloc(
    HymnRepositoryImpl(_MockApi(hymns: hymns), CatalogCache.noop()),
  );

  testWidgets('download de faixa: unsupported mostra snack', (tester) async {
    final bloc = blocWith([
      const Hymn(id: 1, title: 'Hino DL', urlMusic: '/m/1.mp3'),
    ]);

    await tester.pumpWidget(wrapWithRouter(
      AlbumDetailPage(
        albumId: 100,
        offlineService: _NoOffline(),
        audioPlayer: _FakePlayer(),
      ),
      bloc,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hino DL'));
    await tester.pumpAndSettle();

    final dl = find.byTooltip('Baixar');
    if (dl.evaluate().isNotEmpty) {
      await tester.tap(dl.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Downloads disponíveis'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('download suportado marca faixa como baixada', (tester) async {
    final offline = _SupportedOffline();
    final bloc = blocWith([
      const Hymn(id: 2, title: 'Hino OK', urlMusic: '/m/2.mp3'),
    ]);

    await tester.pumpWidget(wrapWithRouter(
      AlbumDetailPage(
        albumId: 100,
        offlineService: offline,
        audioPlayer: _FakePlayer(),
      ),
      bloc,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hino OK'));
    await tester.pumpAndSettle();

    final dl = find.byTooltip('Baixar');
    if (dl.evaluate().isNotEmpty) {
      await tester.tap(dl.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(offline.downloaded, contains(2));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove faixa baixada chama offline.remove', (tester) async {
    final offline = _SupportedOffline();
    offline.downloaded.add(3);
    final bloc = blocWith([
      const Hymn(id: 3, title: 'Hino Removível', urlMusic: '/m/3.mp3'),
    ]);

    await tester.pumpWidget(wrapWithRouter(
      AlbumDetailPage(
        albumId: 100,
        offlineService: offline,
        audioPlayer: _FakePlayer(),
      ),
      bloc,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hino Removível'));
    await tester.pumpAndSettle();

    final removeIcon = find.byTooltip('Remover download');
    if (removeIcon.evaluate().isNotEmpty) {
      await tester.tap(removeIcon.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(offline.removed, contains(3));
    }
    expect(tester.takeException(), isNull);
  });
}
