library;

import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/hymn_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';

/// Implementação offline-first de [HymnRepository].
///
/// Estratégia:
/// 1. Tenta cache local (TTL 24h).
/// 2. Se cache expirado/inexistente, busca remoto.
/// 3. Se remoto falhar, usa cache expirado como fallback.
/// 4. Sempre atualiza cache após sucesso remoto.
class HymnRepositoryImpl implements HymnRepository {
  final LouvorjaApiClient _api;
  final CatalogCache _cache;

  /// IDs excluídos do catálogo (hardcoded no Electron).
  static const _excludedAlbumIds = {712, 629};

  /// Cache em memória das categorias já processadas.
  List<AlbumCategory>? _categoriesCache;
  List<Album>? _flatAlbumsCache;

  HymnRepositoryImpl(this._api, this._cache);

  @override
  Future<List<AlbumCategory>> getCategories() async {
    if (_categoriesCache != null) return _categoriesCache!;

    // Tenta cache local primeiro
    final cached = _cache.read('categories');
    if (cached != null) {
      final parsed = _parseCategories(cached);
      if (parsed.isNotEmpty) {
        _categoriesCache = parsed;
        return parsed;
      }
    }

    // Busca remoto: categorias primeiro, depois hinários (sequencial para respeitar rate limit)
    try {
      final categories = await _api.fetchCategories();
      final hymnal = await _api.fetchHymnal();
      // A API nao publica es_hymnal_1996 (404). Não requisitar para ES:
      // é um catálogo opcional e não pode poluir o console nem derrubar
      // categorias/hinário atual. Outros idiomas mantêm o fetch tolerante.
      List<Hymn> hymnal1996 = const [];
      if (_api.languagePrefix != 'es') {
        try {
          hymnal1996 = await _api.fetchHymnal1996();
        } catch (_) {
          // Sem Hinário 1996 para o idioma atual — ocultar a categoria.
        }
      }

      // Hinários como categorias virtuais, quando a API retornou dados.
      final categoriesWithHymnals = <AlbumCategory>[
        if (hymnal.isNotEmpty)
          AlbumCategory(
            id: 0,
            name: 'Hinário Adventista',
            albums: [
              Album(
                id: _hymnalCurrentId,
                name: 'Hinário Adventista (Atual)',
                subtitle: '${hymnal.length} hinos',
                trackCount: hymnal.length,
                coverUrl: 'asset:hymnal.jpeg',
              ),
            ],
          ),
        if (hymnal1996.isNotEmpty)
          AlbumCategory(
            id: 0,
            name: 'Hinário Adventista',
            albums: [
              Album(
                id: _hymnal1996Id,
                name: 'Hinário Adventista (1996)',
                subtitle: '${hymnal1996.length} hinos',
                trackCount: hymnal1996.length,
                coverUrl: 'asset:hymnal_1996.jpeg',
              ),
            ],
          ),
        ..._filterExcluded(categories),
      ];

      _categoriesCache = categoriesWithHymnals;
      _flatAlbumsCache = null;
      // Persiste em disco: cold start SEM internet serve daqui (offline-first).
      // Sem isto o cache só existia em memória e o app fechado+offline
      // mostrava "verifique sua conexão" mesmo com conteúdo baixado.
      _cache.write(
        'categories',
        categoriesWithHymnals.map((c) => c.toJson()).toList(),
      );
      return _categoriesCache!;
    } catch (_) {
      // Fallback: cache expirado
      if (cached != null) {
        final parsed = _filterExcluded(_parseCategories(cached));
        return parsed;
      }
      rethrow;
    }
  }

  /// ID especial para o hinário atual (não é um album real na API).
  static const _hymnalCurrentId = -1;
  static const _hymnal1996Id = -2;

  @override
  Future<List<Hymn>> getHymnsByAlbum(int albumId) async {
    // TODO offline-first: hinários também precisam de cache. Antes desta
    // correção eles retornavam direto da API; com internet desligada a tela
    // quebrava ANTES de o PlaybackResolver alcançar o MP3 já baixado.
    final cacheKey = 'album_$albumId';

    final cached = _cache.read(cacheKey);
    if (cached != null) {
      final parsed = _parseHymns(cached);
      if (parsed.isNotEmpty) return parsed;
    }

    try {
      final hymns = albumId == _hymnalCurrentId
          ? await _api.fetchHymnal()
          : albumId == _hymnal1996Id
          ? await _api.fetchHymnal1996()
          : await _api.fetchAlbumHymns(albumId);
      _cache.write(cacheKey, hymns.map((h) => h.toJson()).toList());
      return hymns;
    } catch (_) {
      // API fora: cache fresco primeiro, depois STALE (expirado) — melhor
      // catálogo velho do que tela de erro (incidente API 429 2026-08-16).
      final fresh = cached ?? _cache.readStale(cacheKey);
      if (fresh != null) {
        final parsed = _parseHymns(fresh);
        if (parsed.isNotEmpty) return parsed;
      }
      rethrow;
    }
  }

  @override
  Future<List<Hymn>> searchHymns(String query) async {
    final hymns = await _api.fetchMusicIndex();
    final q = query.toLowerCase().trim();
    return hymns.where((h) {
      final title = (h.title ?? '').toLowerCase();
      final number = h.number?.toString() ?? '';
      return title.contains(q) || number.contains(q);
    }).toList();
  }

  @override
  Future<Hymn> getHymnDetails(int id) => _api.fetchMusic(id);

  @override
  Future<Hymn?> getHymn(int id) async {
    final hymns = await _api.fetchMusicIndex();
    for (final h in hymns) {
      if (h.id == id) return h;
    }
    return null;
  }

  @override
  List<Album> getAllAlbums() {
    if (_flatAlbumsCache != null) return _flatAlbumsCache!;
    final result = <Album>[];
    for (final cat in _categoriesCache ?? const <AlbumCategory>[]) {
      result.addAll(cat.albums);
    }
    _flatAlbumsCache = result;
    return result;
  }

  List<AlbumCategory> _filterExcluded(List<AlbumCategory> categories) {
    return categories.map((cat) {
      final filtered = cat.albums
          .where((a) => !_excludedAlbumIds.contains(a.id))
          .toList();
      return AlbumCategory(id: cat.id, name: cat.name, albums: filtered);
    }).toList();
  }

  List<AlbumCategory> _parseCategories(dynamic data) {
    if (data is! List) return const [];
    return data
        .map((e) => AlbumCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<Hymn> _parseHymns(dynamic data) {
    if (data is! List) return const [];
    return data.map((e) => Hymn.fromJson(e as Map<String, dynamic>)).toList();
  }
}
