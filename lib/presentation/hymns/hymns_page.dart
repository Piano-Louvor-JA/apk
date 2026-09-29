library;

import "dart:async";

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:louvorja_piano_mobile/data/datasources/local/path_provider_web.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/global_search_service.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_catalog_provider.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_service.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_player_adapter.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'bloc/hymns_bloc.dart';

const _apiToken = String.fromEnvironment('API_TOKEN', defaultValue: '');

// coverage:ignore-start
// Helper so chamado quando testBloc e null (initBloc assincrono)
String _languageCode(BuildContext context) {
  try {
    return context.locale.languageCode;
  } catch (_) {
    // Testes/unitários ou host sem EasyLocalization.
    return 'pt';
  }
}
// coverage:ignore-end

class HymnsPage extends StatefulWidget {
  final HymnsBloc? testBloc;

  const HymnsPage({super.key, this.testBloc});

  @override
  State<HymnsPage> createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage> {
  HymnsBloc? _bloc;
  String? _loadedLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se um bloc de teste foi injetado, pula inicializacao assincrona.
    if (widget.testBloc != null) {
      _bloc ??= widget.testBloc;
      return;
    }
    final language = _languageCode(context);
    if (_loadedLanguage != language) {
      _loadedLanguage = language;
      _bloc?.close();
      _bloc = null;
      _initBloc(language);
    }
  }

  Future<void> _initBloc(String languagePrefix) async {
    // coverage:ignore-start
    final api = LouvorjaApiImpl(
      baseUrls: ApiConfig.databaseUrls(),
      filesUrls: ApiConfig.filesUrls(),
      apiToken: _apiToken,
      languagePrefix: languagePrefix,
    );

    CatalogCache cache;
    if (kIsWeb) {
      // Web: nao tem dart:io; cache e no-op.
      cache = CatalogCache.noop();
    } else {
      // Mobile: cache em disco.
      final dir = await getApplicationDocumentsDirectory();
      cache = CatalogCache(dir);
    }

    final repo = HymnRepositoryImpl(api, cache);
    final bloc = HymnsBloc(
      repo,
      catalogProvider: hymnCatalogProvider,
      // Offline-first: sem rede a home mostra a BIBLIOTECA BAIXADA.
      offlinePort: kIsWeb ? null : createOfflineMusicService(),
    );
    bloc.add(HymnsLoadRequested());
    if (mounted) setState(() => _bloc = bloc);
    // coverage:ignore-end
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bloc == null) {
      return Scaffold(
        appBar: AppBar(title: Text('hymns.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider<HymnsBloc>.value(
      value: _bloc!,
      child: const _HymnsView(),
    );
  }
}

class _HymnsView extends StatefulWidget {
  const _HymnsView();

  @override
  State<_HymnsView> createState() => _HymnsViewState();
}

class _HymnsViewState extends State<_HymnsView> {
  String _searchQuery = '';
  bool _isSearching = false;
  List<Hymn> _searchResults = const [];
  bool _searchLoading = false;
  bool _downloadingAll = false;
  int? _downloadAllProgress; // 0..100 (músicas, não álbuns)
  int? _downloadAllCurrent; // músicas concluídas
  int? _downloadAllTotal; // total de músicas no lote
  String? _downloadAllAlbum; // álbum em curso

  Timer? _debounce;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _searchQuery = q);
    if (q.length < 3) {
      setState(() {
        _searchResults = const [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(q));
  }

  Future<void> _doSearch(String query) async {
    if (!mounted) return;
    try {
      final repo = context.read<HymnsBloc>().repository;
      final results = await repo.searchHymns(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searchLoading = false;
      });
    }
  }

  // coverage:ignore-start
  Future<void> _openSearchResult(BuildContext context, Hymn hymn) async {
    try {
      final repo = context.read<HymnsBloc>().repository;
      final detail = await repo.getHymnDetails(hymn.id);
      if (!context.mounted) return;

      final url = detail.urlMusic ?? '';
      if (url.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('errors.notFound'.tr())));
        return;
      }

      final source = DownloadUrlBuilder.build(url);
      final player = HymnAudioPlayer.instance;
      final adapter = HymnPlayerAdapter(player);

      nowPlaying.start(
        hymnId: hymn.id,
        title: detail.title ?? '',
        album: '',
        albumId: 0,
        durationMs: detail.durationMs,
        detail: detail,
        audioSource: source,
      );
      await player.playUrl(source);

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NowPlayingPage(
            detail: detail,
            instrumental: false,
            player: adapter,
            filesUrl: ApiConfig.urlFiles,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('errors.connection'.tr())));
    }
  }
  // coverage:ignore-end

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Baixa todas as coletaneas disponiveis (feature herdada do desktop:
  /// download sob demanda de toda a biblioteca).
  // coverage:ignore-start
  Future<void> _downloadEverything(List<AlbumCategory> categories) async {
    final offline = createOfflineMusicService();
    if (!offline.isSupported || _downloadingAll) return;

    final albums = <Album>[];
    for (final cat in categories) {
      albums.addAll(cat.albums);
    }

    final repo = context.read<HymnsBloc>().repository;

    // Pré-conta músicas p/ progresso por FAIXA (o contador por álbum era
    // vago: um álbum de 70 músicas não mudava o número por minutos).
    // Músicas JÁ baixadas saem do lote — re-baixar o que tá salvo era o
    // feedback do Rafael ('se já foi baixado não quero baixar de novo').
    var totalMusics = 0;
    final alreadyOffline = <int>{};
    for (final album in albums) {
      try {
        final hymns = await repo.getHymnsByAlbum(album.id);
        for (final hymn in hymns) {
          if (await offline.localPathFor(hymn.id) != null) {
            alreadyOffline.add(hymn.id);
          } else {
            totalMusics++;
          }
        }
      } catch (_) {}
    }
    if (totalMusics == 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tudo já está baixado!')));
        setState(() => _downloadingAll = false);
      }
      return;
    }

    setState(() {
      _downloadingAll = true;
      _downloadAllProgress = 0;
      _downloadAllCurrent = 0;
      _downloadAllTotal = totalMusics;
    });

    var done = 0;
    var failed = 0;
    for (final album in albums) {
      if (mounted) {
        setState(() => _downloadAllAlbum = album.name);
      }
      try {
        final hymns = await repo.getHymnsByAlbum(album.id);
        for (final hymn in hymns) {
          if (alreadyOffline.contains(hymn.id)) continue; // já salvo: pula
          try {
            final detail = await repo.getHymnDetails(hymn.id);
            final url = detail.urlMusic ?? '';
            if (url.isNotEmpty) {
              // URL encodada: paths da API tem espacos/acento e o request
              // quebra sem encoding (bug dos downloads 100% falhando).
              await offline.download(
                musicId: hymn.id,
                url: DownloadUrlBuilder.build(url),
              );
              final OfflineMusicPort offlinePort = offline;
              if (offlinePort is OfflineLibraryPort) {
                await (offlinePort as OfflineLibraryPort).saveMetadata(
                  musicId: hymn.id,
                  title: hymn.title ?? 'Hino #${hymn.id}',
                  number: hymn.number?.toString(),
                  albumId: album.id,
                  albumName: album.name,
                );
              }
            }
          } catch (_) {
            failed++; // falha de música não aborta o lote
          }
          done++;
          // Pausa entre faixas: respeita rate limiting da API.
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (mounted && done % 3 == 0) {
            setState(() {
              _downloadAllCurrent = done;
              _downloadAllProgress = (done * 100 ~/ totalMusics);
            });
          }
        }
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      setState(() {
        _downloadAllCurrent = done;
        _downloadAllProgress =
            (done * 100 ~/ (totalMusics == 0 ? 1 : totalMusics));
      });
    }

    if (mounted) {
      setState(() {
        _downloadingAll = false;
        _downloadAllProgress = null;
      });
      if (failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'downloads.albumErrors'.tr(
                namedArgs: {'count': '$failed', 'total': '${albums.length}'},
              ),
            ),
          ),
        );
      }
    }
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'hymns.searchHint'.tr(),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: theme.textTheme.bodyLarge,
                onChanged: _onSearchChanged,
              )
            : Text('hymns.title'.tr()),
        actions: [
          // Playlists (seleção de hinos do acervo, local)
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Playlists',
            onPressed: () => context.push('/hymns/playlists'),
          ),
          // Coletâneas da comunidade (custom da API)
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Coletâneas da Comunidade',
            onPressed: () => context.push('/hymns/custom'),
          ),
          BlocBuilder<HymnsBloc, HymnsState>(
            builder: (context, state) {
              if (state is! HymnsLoaded) return const SizedBox.shrink();
              return _DownloadAllButton(
                downloading: _downloadingAll,
                progress: _downloadAllProgress,
                current: _downloadAllCurrent,
                total: _downloadAllTotal,
                album: _downloadAllAlbum,
                onPressed: () => _downloadEverything(state.categories),
              );
            },
          ),
          IconButton(
            key: const Key('hymns-search-toggle'),
            icon: Icon(_isSearching ? TablerIcons.x : TablerIcons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchResults = const [];
                  _searchLoading = false;
                }
              });
            },
          ),
        ],
      ),
      body: BlocBuilder<HymnsBloc, HymnsState>(
        builder: (context, state) {
          if (state is HymnsLoading || state is HymnsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HymnsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      TablerIcons.wifiOff,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      state.code.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    FilledButton.icon(
                      onPressed: () => context.read<HymnsBloc>().add(
                        HymnsRefreshRequested(),
                      ),
                      icon: const Icon(TablerIcons.refresh, size: 18),
                      label: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is HymnsLoaded) {
            // Busca por musicas quando ha 3+ caracteres.
            if (_searchQuery.length >= 3) {
              if (_searchLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_searchResults.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TablerIcons.musicOff,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Nenhuma musica encontrada',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.s4),
                itemCount: _searchResults.length,
                itemBuilder: (context, i) {
                  final h = _searchResults[i];
                  return ListTile(
                    leading: Text(
                      h.number != null ? '#${h.number}' : '${h.id}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      h.title ?? 'Hino #${h.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      TablerIcons.chevronRight,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => _openSearchResult(context, h),
                  );
                },
              );
            }

            // Sem busca: lista coletaneas (comportamento original).
            final filteredCategories = GlobalSearchService.filterAlbums(
              state.categories,
              '',
            );

            final allAlbums = <Album>[];
            for (final cat in filteredCategories) {
              allAlbums.addAll(cat.albums);
            }
            if (allAlbums.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      TablerIcons.playlist,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      'common.empty'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              // coverage:ignore-start
              // onRefresh exercitado via fling mas coverage_collector nao reporta
              onRefresh: () async {
                context.read<HymnsBloc>().add(HymnsRefreshRequested());
              },
              // coverage:ignore-end
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s4),
                children: [
                  for (final cat in filteredCategories) ...[
                    if (cat.name != null && cat.albums.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.s4,
                          bottom: AppSpacing.s2,
                        ),
                        child: Text(
                          cat.name!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    for (final album in cat.albums) _AlbumCard(album: album),
                  ],
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = album.coverUrl;
    // coverage:ignore-start
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    final isAsset = hasCover && coverUrl.startsWith('asset:');
    final assetName = isAsset ? coverUrl.substring('asset:'.length) : null;
    final fullCoverUrl = hasCover && !isAsset
        ? DownloadUrlBuilder.build(coverUrl)
        : null;
    // coverage:ignore-end

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/hymns/${album.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: assetName != null
                      // coverage:ignore-line
                      ? Image.asset(
                          // coverage:ignore-line
                          'assets/images/library/$assetName',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          // coverage:ignore-line
                          errorBuilder: (_, __, ___) =>
                              // coverage:ignore-line
                              _CoverPlaceholder(theme: theme, album: album),
                        )
                      : fullCoverUrl != null
                      // coverage:ignore-start
                      // CachedNetworkImage faz HTTP real.
                      // BMP da API nao decodifica no Flutter Web;
                      // erro cai no placeholder com cor do album.
                      ? CachedNetworkImage(
                          imageUrl: fullCoverUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              _CoverPlaceholder(theme: theme, album: album),
                          errorWidget: (_, __, ___) =>
                              _CoverPlaceholder(theme: theme, album: album),
                        )
                      // coverage:ignore-end
                      : _CoverPlaceholder(theme: theme, album: album),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name ?? 'Sem título',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (album.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          album.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  TablerIcons.chevronRight,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final ThemeData theme;
  final Album? album;

  const _CoverPlaceholder({required this.theme, this.album});

  @override
  Widget build(BuildContext context) {
    final bg = album?.color ?? theme.colorScheme.surfaceContainerHigh;
    final initial = (album?.name ?? '?')[0].toUpperCase();

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: bg.computeLuminance() > 0.5
              ? Colors.black.withValues(alpha: 0.7)
              // coverage:ignore-line
              : Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// Botao "Baixar todas as coletaneas" na AppBar da aba Hinos.
/// Mostra progresso durante o download em lote.
class _DownloadAllButton extends StatelessWidget {
  final bool downloading;
  final int? progress;
  final int? current;
  final int? total;
  final String? album;
  final VoidCallback onPressed;

  const _DownloadAllButton({
    required this.downloading,
    required this.progress,
    required this.current,
    required this.total,
    required this.onPressed,
    this.album,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (downloading) {
      // Banner compacto: contador de músicas + barra + álbum em curso.
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (album != null)
              Text(
                album!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            Text(
              '$current/$total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              width: 88,
              child: LinearProgressIndicator(
                value: (progress ?? 0) / 100,
                minHeight: 3,
              ),
            ),
          ],
        ),
      );
    }
    return IconButton(
      tooltip: 'downloads.downloadAll'.tr(),
      icon: const Icon(TablerIcons.download),
      onPressed: onPressed,
    );
  }
}
