// ignore_for_file: unused_import, unused_element_parameter
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart' show ProgressCallback;
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/hymn_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/album_detail_page.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final List<Hymn> hymns;
  final Hymn? detail;
  final bool fail;
  final bool failDetail;
  int fetchMusicCalls = 0;

  _MockApi({
    this.hymns = const [],
    this.detail,
    this.fail = false,
    this.failDetail = false,
  });

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    if (fail) throw Exception('network');
    return hymns;
  }

  @override
  Future<Hymn> fetchMusic(int musicId) async {
    fetchMusicCalls++;
    if (fail || failDetail) throw Exception('network');
    return detail ??
        Hymn(id: musicId, title: 'Test', urlMusic: '/musics/test.mp3');
  }

  @override
  Future<List<AlbumCategory>> fetchCategories() async => [];
  @override
  Future<List<Hymn>> fetchHymnal() async => [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => [];
  @override
  String resolveMediaUrl(String relativePath) =>
      'https://example.com/$relativePath';
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

class _FakePlayer implements HymnAudioPlayer {
  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration> get durationStream => const Stream.empty();

  @override
  Stream<void> get completionStream => const Stream.empty();

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double v) async {}

  final _stream = StreamController<bool>.broadcast();
  bool paused = false;
  String? playedUrl;

  @override
  String? get currentUrl => playedUrl;
  @override
  bool get isPlaying => playedUrl != null && !paused;
  @override
  Stream<bool> get playingStream => _stream.stream;
  @override
  Future<void> pause() async {
    paused = true;
    _stream.add(false);
  }

  @override
  Future<void> playUrl(String url) async {
    playedUrl = url;
    paused = false;
    _stream.add(true);
  }

  @override
  Future<void> stop() async {
    paused = true;
    playedUrl = null;
    _stream.add(false);
  }

  @override
  Future<void> toggleUrl(String url) async =>
      isPlaying && playedUrl == url ? pause() : playUrl(url);
  @override
  void dispose() => _stream.close();
}

Widget _wrap(HymnsBloc bloc, Widget child) => MaterialApp(
  home: BlocProvider<HymnsBloc>.value(value: bloc, child: child),
);

void main() {
  testWidgets('AlbumDetailPage mostra loading', (tester) async {
    final repo = HymnRepositoryImpl(
      _MockApi(hymns: [const Hymn(id: 1, title: 'Hino 1')]),
      CatalogCache.noop(),
    );
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    // Primeiro frame: loading visível antes de qualquer dado chegar.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Consome os timeouts do fluxo offline (timers não podem pendurar).
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('AlbumDetailPage mostra lista de hinos', (tester) async {
    final api = _MockApi(
      hymns: [
        const Hymn(id: 1, title: 'Hino A', number: 1),
        const Hymn(id: 2, title: 'Hino B', number: 2, hasInstrumental: true),
      ],
    );
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hino A'), findsOneWidget);
    expect(find.text('Hino B'), findsOneWidget);
  });

  testWidgets('AlbumDetailPage mostra empty state quando sem hinos', (
    tester,
  ) async {
    final repo = HymnRepositoryImpl(_MockApi(hymns: []), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerIcons.playlist), findsOneWidget);
  });

  testWidgets('AlbumDetailPage mostra erro quando API falha', (tester) async {
    final repo = HymnRepositoryImpl(_MockApi(fail: true), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerIcons.alertCircle), findsOneWidget);
  });

  testWidgets('AlbumDetailPage tem campo de busca', (tester) async {
    final api = _MockApi(hymns: [const Hymn(id: 1, title: 'Hino 1')]);
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerIcons.search), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('AlbumDetailPage mostra botao play e instrumental', (
    tester,
  ) async {
    final api = _MockApi(
      hymns: [
        const Hymn(id: 1, title: 'Hino X', number: 1, hasInstrumental: true),
      ],
    );
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    // Botao play (row + botao Tocar tudo do AppBar usam o mesmo icone)
    expect(find.byIcon(TablerIcons.playerPlayFilled), findsAtLeastNWidgets(1));
    // Botao instrumental (piano)
    expect(find.byIcon(TablerIcons.piano), findsOneWidget);
  });

  testWidgets('AlbumDetailPage sem instrumental so mostra play', (
    tester,
  ) async {
    final api = _MockApi(
      hymns: [
        const Hymn(id: 1, title: 'Sem Instrumental', hasInstrumental: false),
      ],
    );
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerIcons.playerPlayFilled), findsAtLeastNWidgets(1));
    expect(find.byIcon(TablerIcons.piano), findsNothing);
  });

  testWidgets('play muda para pause e pause restaura play', (tester) async {
    final player = _FakePlayer();
    final api = _MockApi(
      hymns: [const Hymn(id: 1, title: 'Hino tocável', durationMs: 125000)],
      detail: const Hymn(id: 1, urlMusic: '/musics/test.mp3'),
    );
    final bloc = HymnsBloc(HymnRepositoryImpl(api, CatalogCache.noop()));

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(
          albumId: 100,
          audioPlayer: player,
          offlineService: _FakeOfflinePort(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reproduzir'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(player.playedUrl, contains('/musics/test.mp3'));
    expect(find.byTooltip('Pausar'), findsOneWidget);
    expect(find.byIcon(TablerIcons.playerPauseFilled), findsOneWidget);

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(player.paused, isTrue);
    expect(find.byTooltip('Reproduzir'), findsOneWidget);
  });

  testWidgets('tap no hino expande e recolhe a letra', (tester) async {
    final api = _MockApi(
      hymns: [
        const Hymn(
          id: 1,
          title: 'Hino com letra',
          lyric: 'Primeira linha\nSegunda linha',
        ),
      ],
    );
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      _wrap(
        bloc,
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Primeira linha\nSegunda linha'), findsNothing);
    await tester.tap(find.text('Hino com letra'));
    await tester.pump();
    expect(find.text('Primeira linha\nSegunda linha'), findsOneWidget);

    await tester.tap(find.text('Hino com letra'));
    await tester.pump();
    expect(find.text('Primeira linha\nSegunda linha'), findsNothing);
  });

  _offlineGroup();
  _onlineFullListGroup();
}

// ===== Testes do modo offline (downloads persistidos + playback local) =====

class _FakeOfflinePort implements OfflineMusicPort {
  final Set<int> local = {};
  final bool supported;

  _FakeOfflinePort({this.supported = true});

  @override
  bool get isSupported => supported;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    if (!supported) return null;
    return local.contains(musicId) ? '/local/$musicId.mp3' : null;
  }

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    local.add(musicId);
    return '/local/$musicId.mp3';
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    local.remove(musicId);
  }
}

void _offlineGroup() {
  group('AlbumDetailPage offline', () {
    testWidgets('faixa baixada toca do arquivo local (sem API)', (
      tester,
    ) async {
      final offline = _FakeOfflinePort();
      offline.local.add(1);
      final player = _FakePlayer();

      // Lista serve do cache/mock; detalhe falha (simula offline no play).
      final api = _MockApi(
        hymns: [const Hymn(id: 1, title: 'Hino Baixado', number: 1)],
        failDetail: true,
      );
      final repo = HymnRepositoryImpl(api, CatalogCache.noop());
      final bloc = HymnsBloc(repo);

      await tester.pumpWidget(
        _wrap(
          bloc,
          AlbumDetailPage(
            albumId: 100,
            audioPlayer: player,
            offlineService: offline,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reproduzir'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        player.playedUrl,
        '/local/1.mp3',
        reason: 'baixado deve tocar do disco sem consultar a API',
      );
      expect(
        api.fetchMusicCalls,
        0,
        reason: 'play offline não deve requisitar o detalhe na API',
      );
    });

    testWidgets('icone de baixado aparece ao abrir pagina com faixa no disco', (
      tester,
    ) async {
      final offline = _FakeOfflinePort();
      offline.local.add(1);

      final api = _MockApi(
        hymns: [const Hymn(id: 1, title: 'Hino Salvo', number: 1)],
      );
      final repo = HymnRepositoryImpl(api, CatalogCache.noop());
      final bloc = HymnsBloc(repo);

      await tester.pumpWidget(
        _wrap(bloc, AlbumDetailPage(albumId: 100, offlineService: offline)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(TablerIcons.checks),
        findsOneWidget,
        reason: 'faixa baixada deve exibir check de baixado',
      );
    });
  });
}

// ===== Regressão 2026-08-16: online mostra TODAS as faixas =====
// Bug: o filtro offline rodava também ONLINE e escondia as não baixadas.
void _onlineFullListGroup() {
  group('AlbumDetailPage online (regressão)', () {
    testWidgets('online com downloads ainda lista faixas NÃO baixadas', (
      tester,
    ) async {
      final offline = _FakeOfflinePort();
      offline.local.add(1); // só a faixa 1 está no disco

      // Catálogo tem 1 (baixada) e 2 (NÃO baixada).
      final api = _MockApi(
        hymns: const [
          Hymn(id: 1, title: 'Hino Baixado', number: 1),
          Hymn(id: 2, title: 'Hino Só Online', number: 2),
        ],
      );
      final repo = HymnRepositoryImpl(api, CatalogCache.noop());
      final bloc = HymnsBloc(repo);

      await tester.pumpWidget(
        _wrap(
          bloc,
          AlbumDetailPage(
            albumId: 100,
            offlineService: offline,
            audioPlayer: _FakePlayer(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hino Baixado'), findsOneWidget);
      expect(
        find.text('Hino Só Online'),
        findsOneWidget,
        reason: 'online deve listar tudo, não só o que está no disco',
      );
    });
  });
}
