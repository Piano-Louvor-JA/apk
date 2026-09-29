library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/album_detail_page.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final List<Hymn> hymns;
  final bool fail;

  _MockApi({this.hymns = const [], this.fail = false});

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    if (fail) throw Exception('network');
    return hymns;
  }

  @override
  Future<Hymn> fetchMusic(int musicId) async =>
      Hymn(id: musicId, title: 'Test', urlMusic: '/musics/test.mp3');

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
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

void main() {
  // GoRouter ancestral para context.pop/canPop funcionarem
  Widget wrapWithRouter(Widget child, HymnsBloc bloc) {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, __) =>
              BlocProvider<HymnsBloc>.value(value: bloc, child: child),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('AlbumDetailPage TextField onChanged', (tester) async {
    final repo = HymnRepositoryImpl(
      _MockApi(hymns: [const Hymn(id: 1, title: 'Hino 1')]),
      CatalogCache.noop(),
    );
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      wrapWithRouter(
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
        bloc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'filter');
    await tester.pump();
  });

  testWidgets('AlbumDetailPage botao back faz pop', (tester) async {
    final repo = HymnRepositoryImpl(
      _MockApi(hymns: [const Hymn(id: 1, title: 'Hino 1')]),
      CatalogCache.noop(),
    );
    final bloc = HymnsBloc(repo);

    await tester.pumpWidget(
      wrapWithRouter(
        AlbumDetailPage(albumId: 100, offlineService: _FakeOfflinePort()),
        bloc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerIcons.arrowLeft));
    await tester.pumpAndSettle();
  });

  testWidgets('AlbumDetailPage botao retry faz pop', (tester) async {
    final repo = HymnRepositoryImpl(_MockApi(fail: true), CatalogCache.noop());
    final bloc = HymnsBloc(repo);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, __) => BlocProvider<HymnsBloc>.value(
            value: bloc,
            child: AlbumDetailPage(
              albumId: 100,
              offlineService: _FakeOfflinePort(),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Navega para /detail (adiciona na pilha)
    router.push('/detail');
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerIcons.alertCircle), findsOneWidget);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
  });
}

class _FakeOfflinePort implements OfflineMusicPort {
  @override
  bool get isSupported => false;

  @override
  Future<String?> localPathFor(
    int musicId, {
    bool instrumental = false,
  }) async => null;

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {}
}
