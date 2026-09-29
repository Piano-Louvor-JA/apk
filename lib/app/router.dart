/// Configuracao de rotas com go_router.
///
/// 4 tabs: Inicio, Hinos, Ferramentas, Mais.
/// Usa StatefulShellRoute.indexedStack para preservar estado de cada tab.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import '../core/services/global_search_service.dart';
import '../core/services/hymn_catalog_provider.dart';
import '../core/services/search_sources.dart';
import '../data/datasources/remote/louvorja_api_impl.dart';
import '../data/repositories/bible_repository_impl.dart';
import '../data/repositories/hymn_repository_impl.dart';
import '../data/datasources/local/catalog_cache.dart';
import '../domain/entities/hymn.dart';
import '../presentation/home/home_page.dart';
import '../presentation/hymns/hymns_page.dart';
import '../presentation/hymns/album_detail_page.dart';
import '../presentation/custom/custom_collections_page.dart';
import '../presentation/playlists/playlists_page.dart';
import '../presentation/search/global_search_page.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/settings/terms_page.dart';
import '../presentation/shared/widgets/main_navigation.dart';
import '../presentation/tools/tools_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigation(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Inicio
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ],
        ),
        // Tab 1: Hinos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hymns',
              builder: (context, state) => const HymnsPage(),
              routes: [
                // ATENÇÃO: 'custom' DEVE vir antes de ':albumId' — o go_router
                // casa rotas em ordem de declaração. Se ':albumId' viesse
                // primeiro, push('/hymns/custom') casaria com o padrão do
                // álbum (albumId='custom' → parse falha → 0 → abria o
                // Hinário Atual). Bug real encontrado em device 10/09.
                GoRoute(
                  path: 'playlists',
                  builder: (context, state) => const PlaylistsPage(),
                ),
                GoRoute(
                  path: 'custom',
                  builder: (context, state) => const CustomCollectionsPage(),
                ),
                GoRoute(
                  path: ':albumId',
                  builder: (context, state) => AlbumDetailPage(
                    albumId:
                        int.tryParse(state.pathParameters['albumId'] ?? '') ??
                        0,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Tab 2: Ferramentas (Liturgia + Biblia)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tools',
              builder: (context, state) => const ToolsPage(),
            ),
          ],
        ),
        // Tab 3: Mais (Settings)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => SettingsPage(),
              routes: [
                GoRoute(
                  path: 'terms',
                  builder: (context, state) =>
                      const TermsPage(isPrivacy: false),
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) => const TermsPage(isPrivacy: true),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // Busca global (RF-08): fora do shell para abrir em tela cheia.
    // Hinos: catalogo em memoria populado pelo HymnsBloc (instantaneo);
    // fallback para fonte propria se o catalogo ainda nao carregou.
    GoRoute(
      path: '/search',
      builder: (context, state) {
        return GlobalSearchPage(
          service: GlobalSearchService(),
          hymnsProvider: () async {
            if (hymnCatalogProvider.isLoaded) {
              return hymnCatalogProvider.hymns;
            }
            return _searchHymns();
          },
          versesProvider: _searchVerses,
        );
      },
    ),
  ],
);

// --- Fontes reais da busca global (adapters dos repos concretos) ---

HymnRepositoryImpl _searchHymnRepo() {
  final api = LouvorjaApiImpl(
    baseUrls: ApiConfig.databaseUrls(),
    filesUrls: ApiConfig.filesUrls(),
    apiToken: const String.fromEnvironment('API_TOKEN', defaultValue: ''),
  );
  return HymnRepositoryImpl(api, CatalogCache.noop());
}

Future<List<Hymn>> _searchHymns() => SearchSources.loadHymnSources(
  repository: _HymnRepoAdapter(_searchHymnRepo()),
);

Future<List<BibleVerseRef>> _searchVerses() => SearchSources.loadBibleSources(
  repository: _BibleRepoAdapter(
    BibleRepositoryImpl(
      LouvorjaApiImpl(
        baseUrls: ApiConfig.databaseUrls(),
        filesUrls: ApiConfig.filesUrls(),
        apiToken: const String.fromEnvironment('API_TOKEN', defaultValue: ''),
      ),
      CatalogCache.noop(),
    ),
  ),
);

class _HymnRepoAdapter implements HymnRepositoryView {
  final HymnRepositoryImpl _repo;
  _HymnRepoAdapter(this._repo);

  @override
  Future<List<int>> getAlbumIds() async {
    final categories = await _repo.getCategories();
    final ids = <int>[];
    for (final cat in categories) {
      for (final album in cat.albums) {
        ids.add(album.id);
      }
    }
    return ids;
  }

  @override
  Future<List<Hymn>> getHymnsByAlbum(int albumId) =>
      _repo.getHymnsByAlbum(albumId);
}

class _BibleRepoAdapter implements BibleRepositoryView {
  final BibleRepositoryImpl _repo;
  _BibleRepoAdapter(this._repo);

  @override
  Future<List<BibleBookInfo>> getBooks() async {
    final books = await _repo.getBooks();
    return books
        .map((b) => BibleBookInfo(id: b.id, name: b.name, chapters: b.chapters))
        .toList();
  }

  @override
  Future<Map<String, String>> getChapter(
    int versionId,
    int bookId,
    int chapter,
  ) => _repo.getChapter(versionId, bookId, chapter);
}
