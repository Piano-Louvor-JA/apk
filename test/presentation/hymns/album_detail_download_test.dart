library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:dio/dio.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/album_detail_page.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';

/// Onda 78: download/remove por faixa com OfflineMusicPort fake que
/// responde (isSupported true) — cobre _downloadTrack ok/erro e
/// _removeTrack, além do tile "Modo vídeo".
class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';
  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async =>
      [const Hymn(id: 7, title: 'Hino 7', urlMusic: '/m7.mp3')];
  @override
  Future<Hymn> fetchMusic(int musicId) async =>
      Hymn(id: musicId, title: 'T', urlMusic: '/m.mp3');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeOfflineOk implements OfflineMusicPort {
  final Set<int> stored = {};
  bool failDownload = false;

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async =>
      stored.contains(musicId) ? '/tmp/off_$musicId.mp3' : null;

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (failDownload) throw Exception('disco cheio');
    stored.add(musicId);
    onReceiveProgress?.call(1, 2);
    return '/tmp/off_$musicId.mp3';
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    stored.remove(musicId);
  }
}

void main() {
  testWidgets('download por faixa: OK marca como baixada e remove volta',
      (tester) async {
    final offline = _FakeOfflineOk();
    final repo = HymnRepositoryImpl(_MockApi(), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, __) => BlocProvider<HymnsBloc>.value(
            value: bloc,
            child: AlbumDetailPage(albumId: 100, offlineService: offline),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // baixa faixa 7
    await tester.tap(find.byTooltip('Baixar').first);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(offline.stored.contains(7), isTrue);
    expect(find.byTooltip('Remover download'), findsOneWidget);

    // remove download
    await tester.tap(find.byTooltip('Remover download'));
    await tester.pump();
    expect(offline.stored.contains(7), isFalse);
    expect(find.byTooltip('Baixar'), findsOneWidget);
  });

  testWidgets('download por faixa com falha: snack de erro e não marca',
      (tester) async {
    final offline = _FakeOfflineOk()..failDownload = true;
    final repo = HymnRepositoryImpl(_MockApi(), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, __) => BlocProvider<HymnsBloc>.value(
            value: bloc,
            child: AlbumDetailPage(albumId: 100, offlineService: offline),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Baixar').first);
    await tester.pump();
    expect(find.textContaining('Erro ao baixar'), findsOneWidget);
    await tester.pumpAndSettle();
    // não marcou como baixada: botão baixar segue
    expect(find.byTooltip('Baixar'), findsOneWidget);
  });

  testWidgets('tile com botão modo vídeo presente', (tester) async {
    final offline = _FakeOfflineOk();
    final repo = HymnRepositoryImpl(_MockApi(), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, __) => BlocProvider<HymnsBloc>.value(
            value: bloc,
            child: AlbumDetailPage(albumId: 100, offlineService: offline),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Modo vídeo'), findsOneWidget);
    expect(find.byIcon(TablerIcons.slideshow), findsOneWidget);
  });
}
