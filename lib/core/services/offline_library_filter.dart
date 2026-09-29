library;

import '../../domain/entities/album.dart';
import '../../domain/entities/album_category.dart';
import '../../domain/entities/hymn.dart';
import 'offline_music_port.dart';

/// Filtro da biblioteca offline.
///
/// Offline, a home de hinos mostra APENAS o conteúdo baixado — não o
/// catálogo completo do cache. Um álbum aparece somente se tem faixa
/// baixada; a lista de faixas offline de um álbum mostra apenas as
/// baixadas (tocáveis do disco).
///
/// Baseado no índice offline v2 (OfflineLibraryPort.listDownloaded).
/// Adaptadores sem a capacidade (stub Web / fakes antigos) mantêm o
/// comportamento anterior (catálogo do cache) para não regredir
/// ambientes sem download.
class OfflineLibraryFilter {
  const OfflineLibraryFilter._();

  /// Categorias contendo apenas álbuns com pelo menos uma faixa baixada.
  static Future<List<AlbumCategory>> filterCategories({
    required List<AlbumCategory> categories,
    required OfflineMusicPort offline,
  }) async {
    if (offline is! OfflineLibraryPort) return categories;

    final downloaded = await (offline as OfflineLibraryPort).listDownloaded();
    if (downloaded.isEmpty) return const [];
    final downloadedByAlbum = <int, int>{};
    for (final t in downloaded) {
      final albumId = t.albumId;
      if (albumId == null) continue;
      downloadedByAlbum[albumId] = (downloadedByAlbum[albumId] ?? 0) + 1;
    }

    final result = <AlbumCategory>[];
    for (final category in categories) {
      final albums = <Album>[];
      for (final a in category.albums) {
        final count = downloadedByAlbum[a.id];
        if (count == null) continue;
        albums.add(
          Album(
            id: a.id,
            name: a.name,
            subtitle: '$count baixadas',
            coverUrl: a.coverUrl,
            trackCount: count,
            colorHex: a.colorHex,
          ),
        );
      }
      if (albums.isNotEmpty) {
        result.add(
          AlbumCategory(id: category.id, name: category.name, albums: albums),
        );
      }
    }
    return result;
  }

  /// Faixas baixadas de um álbum (para o detalhe offline).
  /// Retorna null quando o adaptador não suporta listagem (mantém o
  /// comportamento do cache) ou quando o álbum não tem downloads.
  static Future<List<Hymn>?> hymnsForAlbum({
    required int albumId,
    required OfflineMusicPort offline,
  }) async {
    if (offline is! OfflineLibraryPort) return null;
    final downloaded = await (offline as OfflineLibraryPort).listDownloaded(
      albumId: albumId,
    );
    if (downloaded.isEmpty) return null;
    return downloaded
        .map(
          (t) => Hymn(
            id: t.musicId,
            title: t.title,
            number: int.tryParse(t.number ?? ''),
          ),
        )
        .toList();
  }
}
