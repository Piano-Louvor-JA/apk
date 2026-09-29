library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_catalog_provider.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

void main() {
  group('HymnCatalogProvider', () {
    test('comeca vazio', () {
      final provider = HymnCatalogProvider();
      expect(provider.hymns, isEmpty);
      expect(provider.isLoaded, isFalse);
    });

    test('setCatalog armazena categorias e marca loaded', () async {
      final provider = HymnCatalogProvider();
      await provider.setCatalog(
        [
          _category(1, 'Hinário', albums: [_album(1)]),
        ],
        hymnLoader: _loader({
          1: [_hymn(10, 'Chegado à Cruz'), _hymn(11, 'Lindo Rancho')],
        }),
      );

      expect(provider.isLoaded, isTrue);
      expect(provider.hymns, hasLength(2));
    });

    test('albumNameById resolve nome do album pai', () async {
      final provider = HymnCatalogProvider();
      await provider.setCatalog(
        [
          _category(1, 'Hinário', albums: [_album(1)]),
          _category(2, 'Louvor JA', albums: [_album(2)]),
        ],
        hymnLoader: _loader({
          1: [_hymn(10, 'Hino A')],
          2: [_hymn(20, 'Hino B')],
        }),
      );

      expect(provider.albumNameByHymnId(10), 'Hinário');
      expect(provider.albumNameByHymnId(20), 'Louvor JA');
      expect(provider.albumNameByHymnId(99), isNull);
    });

    test('setCatalog substitui catalogo anterior (refresh)', () async {
      final provider = HymnCatalogProvider();
      await provider.setCatalog(
        [
          _category(1, 'Old', albums: [_album(1)]),
        ],
        hymnLoader: _loader({
          1: [_hymn(10, 'Antigo')],
        }),
      );
      await provider.setCatalog(
        [
          _category(2, 'New', albums: [_album(2)]),
        ],
        hymnLoader: _loader({
          2: [_hymn(20, 'Novo')],
        }),
      );

      expect(provider.hymns, hasLength(1));
      expect(provider.hymns.first.title, 'Novo');
    });

    test('album com falha no loader nao derruba o restante', () async {
      final provider = HymnCatalogProvider();
      await provider.setCatalog(
        [
          _category(1, 'Ok', albums: [_album(1)]),
          _category(2, 'Falha', albums: [_album(2)]),
        ],
        hymnLoader: (albumId) async {
          if (albumId == 2) throw Exception('boom');
          return [_hymn(10, 'Hino A')];
        },
      );

      expect(provider.hymns, hasLength(1));
    });

    test('albumCoverById resolve cover do album (null quando vazio)', () async {
      final provider = HymnCatalogProvider();
      await provider.setCatalog([
        _category(
          1,
          'Cat',
          albums: [
            _album(7, coverUrl: 'covers/hinario.jpg'),
            _album(8),
            _album(9, coverUrl: ''),
          ],
        ),
      ], hymnLoader: (_) async => []);

      expect(provider.albumCoverById(7), 'covers/hinario.jpg');
      expect(provider.albumCoverById(8), isNull);
      expect(provider.albumCoverById(9), isNull); // string vazia não conta
      expect(provider.albumCoverById(999), isNull);
    });
  });
}

AlbumCategory _category(int id, String name, {List<Album> albums = const []}) =>
    AlbumCategory(id: id, name: name, albums: albums);

Album _album(int id, {String? coverUrl}) =>
    Album(id: id, name: 'Album $id', coverUrl: coverUrl);

Future<List<Hymn>> Function(int) _loader(Map<int, List<Hymn>> map) =>
    (albumId) async => map[albumId] ?? [];

Hymn _hymn(int id, String title) =>
    Hymn(id: id, title: title, hasInstrumental: false);
