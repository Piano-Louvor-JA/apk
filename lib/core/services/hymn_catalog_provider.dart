library;

import '../../domain/entities/album_category.dart';
import '../../domain/entities/hymn.dart';

/// Provider em memoria do catalogo de hinos carregado pelo HymnsBloc.
///
/// A busca global consulta este provider (instantaneo, sem rede) em vez
/// de re-baixar o catalogo. HymnsPage popula ao carregar categorias;
/// o loader de hinos por album e injetado (getHymnsByAlbum do repo).
class HymnCatalogProvider {
  final List<Hymn> _hymns = [];
  final Map<int, String> _albumNameByAlbumId = {};
  final Map<int, String> _albumNameByHymnId = {};
  final Map<int, String> _albumCoverByAlbumId = {};
  bool _isLoaded = false;

  /// Hinos agregados de todos os albuns carregados.
  List<Hymn> get hymns => List.unmodifiable(_hymns);

  /// True apos o primeiro setCatalog concluido.
  bool get isLoaded => _isLoaded;

  /// Nome da categoria (ex: "Hinário Adventista") do album [albumId].
  String? albumNameById(int albumId) => _albumNameByAlbumId[albumId];

  /// Nome da categoria do album que contem o hino [hymnId].
  ///
  /// Resolve na busca global: resultado de hino mostra de qual
  /// coletanea ele veio sem consulta adicional.
  String? albumNameByHymnId(int hymnId) => _albumNameByHymnId[hymnId];

  /// Cover do album [albumId] — usado no quadradinho do now-playing
  /// do Palco (cover do ALBUM, nao da musica/slide).
  ///
  /// Hinarios locais (ids negativos) nao vem da API com coverUrl —
  /// o provider resolve o asset embutido (capa do hinario).
  static const _hymnalCovers = {
    -1: 'asset:assets/images/library/hymnal.jpeg',
    -2: 'asset:assets/images/library/hymnal_1996.jpeg',
  };

  String? albumCoverById(int albumId) =>
      _hymnalCovers[albumId] ?? _albumCoverByAlbumId[albumId];

  /// Carrega categorias + hinos de cada album via [hymnLoader].
  ///
  /// Album que falha e pulado (busca parcial e melhor que nenhuma).
  /// Chamadas subsequentes substituem o catalogo anterior (refresh).
  Future<void> setCatalog(
    List<AlbumCategory> categories, {
    required Future<List<Hymn>> Function(int albumId) hymnLoader,
  }) async {
    final hymns = <Hymn>[];
    final albumNames = <int, String>{};
    final hymnNames = <int, String>{};
    final albumCovers = <int, String>{};

    for (final category in categories) {
      final categoryName = category.name ?? '';
      for (final album in category.albums) {
        albumNames[album.id] = categoryName;
        if (album.coverUrl != null && album.coverUrl!.isNotEmpty) {
          albumCovers[album.id] = album.coverUrl!;
        }
        try {
          final loaded = await hymnLoader(album.id);
          hymns.addAll(loaded);
          for (final hymn in loaded) {
            hymnNames[hymn.id] = categoryName;
          }
        } catch (_) {
          // Album com erro e pulado.
        }
      }
    }

    _hymns
      ..clear()
      ..addAll(hymns);
    _albumNameByAlbumId
      ..clear()
      ..addAll(albumNames);
    _albumNameByHymnId
      ..clear()
      ..addAll(hymnNames);
    _albumCoverByAlbumId
      ..clear()
      ..addAll(albumCovers);
    _isLoaded = true;
  }
}

/// Singleton global do catalogo para a busca global consumir.
///
/// Populado pelo HymnsBloc (via HymnsPage) ao carregar categorias.
/// Nao e Resetado entre telas — refresh de hinos atualiza via setCatalog.
final hymnCatalogProvider = HymnCatalogProvider();
