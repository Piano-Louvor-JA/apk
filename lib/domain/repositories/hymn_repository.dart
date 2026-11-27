library;

import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

/// Contrato do repositório de hinos.
abstract interface class HymnRepository {
  /// Lista todas as categorias com suas coletâneas.
  /// Filtra IDs 712 e 629 (hardcoded no Electron).
  Future<List<AlbumCategory>> getCategories();

  /// Lista hinos de uma coletânea específica.
  Future<List<Hymn>> getHymnsByAlbum(int albumId);

  /// Busca global por número ou título.
  Future<List<Hymn>> searchHymns(String query);

  /// Hino específico por ID no índice local, se disponível.
  Future<Hymn?> getHymn(int id);

  /// Busca os metadados completos do hino na API, incluindo URLs de áudio.
  Future<Hymn> getHymnDetails(int id);

  /// Lista todas as coletâneas (flat, sem categoria).
  List<Album> getAllAlbums();

  /// Override do idioma do CATÁLOGO (API) sem trocar o idioma da UI.
  /// Usado pelo convite "Ver em Português" em idiomas sem catálogo
  /// (paridade desktop: prefixOverride do album-catalog.ts).
  void setCatalogLanguage(String prefix);

  /// Idioma atual do catálogo (API).
  String get catalogLanguage;

  /// Catálogo pt-BR para o backdrop desfocado do convite (idioma sem
  /// catálogo). Não altera o estado do repositório. Falha → vazio.
  Future<List<AlbumCategory>> previewPortugueseCategories();
}
