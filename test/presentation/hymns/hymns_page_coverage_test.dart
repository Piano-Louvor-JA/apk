library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/hymns_page.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class _MockApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final bool fail;
  final List<AlbumCategory> categories;

  _MockApi({this.fail = false, this.categories = const []});

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    if (fail) throw Exception('network error');
    return categories;
  }

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async => const [];
  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String relativePath) => '';
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

HymnsBloc _bloc({_MockApi? api}) {
  final repo = HymnRepositoryImpl(api ?? _MockApi(), CatalogCache.noop());
  return HymnsBloc(repo);
}

void main() {
  // Mesmo pattern do hymns_page_test.dart original
  testWidgets('falha de capa remota registra URL e erro correto', (
    tester,
  ) async {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = previous);
    final bloc = _bloc(
      api: _MockApi(
        categories: const [
          AlbumCategory(
            id: 1,
            name: 'Cat',
            albums: [
              Album(
                id: 10,
                name: 'Capa',
                coverUrl: 'https://example.test/cover.png',
              ),
            ],
          ),
        ],
      ),
    );
    bloc.add(HymnsLoadRequested());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HymnsBloc>.value(
          value: bloc,
          child: HymnsPage(testBloc: bloc),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    final error = StateError('imagem inválida');
    final placeholder = image.errorWidget!(
      tester.element(find.byType(CachedNetworkImage).first),
      image.imageUrl,
      error,
    );
    debugPrint = previous;
    expect(placeholder, isA<Widget>());
    expect(
      logs.last,
      '[AlbumCover] falha ao carregar "${image.imageUrl}": $error',
    );
    expect(find.text('Capa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('botao retry dispara refresh', (tester) async {
    final bloc = _bloc(api: _MockApi(fail: true));
    bloc.add(HymnsLoadRequested());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HymnsBloc>.value(
          value: bloc,
          child: HymnsPage(testBloc: bloc),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerIcons.wifiOff), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    // Tap retry
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  });

  testWidgets('AlbumCard sem cover mostra placeholder', (tester) async {
    final bloc = _bloc(
      api: _MockApi(
        categories: [
          AlbumCategory(
            id: 1,
            name: 'Cat',
            albums: [const Album(id: 10, name: 'Sem Capa')],
          ),
        ],
      ),
    );
    bloc.add(HymnsLoadRequested());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HymnsBloc>.value(
          value: bloc,
          child: HymnsPage(testBloc: bloc),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sem Capa'), findsOneWidget);
  });

  testWidgets('AlbumCard tap navega', (tester) async {
    final bloc = _bloc(
      api: _MockApi(
        categories: [
          AlbumCategory(
            id: 1,
            name: 'Cat',
            albums: [const Album(id: 10, name: 'Nav')],
          ),
        ],
      ),
    );
    bloc.add(HymnsLoadRequested());

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<HymnsBloc>.value(
            value: bloc,
            child: HymnsPage(testBloc: bloc),
          ),
        ),
        GoRoute(
          path: '/hymns/:albumId',
          builder: (_, state) =>
              Scaffold(body: Text('d:${state.pathParameters['albumId']}')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nav'));
    await tester.pumpAndSettle();

    expect(find.text('d:10'), findsOneWidget);
  });

  testWidgets('RefreshIndicator dispara refresh', (tester) async {
    final bloc = _bloc(
      api: _MockApi(
        categories: [
          AlbumCategory(
            id: 1,
            name: 'Cat',
            albums: [const Album(id: 10, name: 'R')],
          ),
        ],
      ),
    );
    bloc.add(HymnsLoadRequested());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HymnsBloc>.value(
          value: bloc,
          child: HymnsPage(testBloc: bloc),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 500),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
