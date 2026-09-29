library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/global_search_service.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';

AlbumCategory _cat(int id, String name, List<Album> albums) =>
    AlbumCategory(id: id, name: name, albums: albums);

Album _album(int id, String name, {String? subtitle}) =>
    Album(id: id, name: name, subtitle: subtitle);

void main() {
  group('GlobalSearchService.filterAlbums', () {
    test('sem query retorna categorias inalteradas', () {
      final cats = [
        _cat(1, 'Hinário', [_album(10, 'Hinário Adventista')]),
      ];
      final result = GlobalSearchService.filterAlbums(cats, '');
      expect(result, hasLength(1));
      expect(result.first.albums, hasLength(1));
    });

    test('busca por nome ignora acentos', () {
      final cats = [
        _cat(1, 'Cat', [_album(10, 'Hinário Adventista')]),
      ];
      final result = GlobalSearchService.filterAlbums(cats, 'hinario');
      expect(result.first.albums, hasLength(1));
    });

    test('busca por subtitulo tambem funciona', () {
      final cats = [
        _cat(1, 'Cat', [_album(10, 'Coletânea', subtitle: 'Edição 1996')]),
      ];
      final result = GlobalSearchService.filterAlbums(cats, '1996');
      expect(result.first.albums, hasLength(1));
    });

    test('album sem match remove a categoria vazia', () {
      final cats = [
        _cat(1, 'Cat A', [_album(10, 'Alpha')]),
        _cat(2, 'Cat B', [_album(20, 'Beta')]),
      ];
      final result = GlobalSearchService.filterAlbums(cats, 'alpha');
      expect(result, hasLength(1));
      expect(result.first.name, 'Cat A');
    });

    test('query curta (1-2 chars) ainda filtra por prefixo do nome', () {
      final cats = [
        _cat(1, 'Cat', [_album(10, 'Louvor JA 2024')]),
      ];
      final result = GlobalSearchService.filterAlbums(cats, 'lo');
      expect(result.first.albums, hasLength(1));
    });
  });

  group('GlobalSearchService.filterVerses', () {
    const verses = {
      '3': 'Porque Deus amou o mundo de tal maneira',
      '16': 'que deu o seu Filho unigênito',
    };

    test('encontra versiculo por texto com acento na query sem acento', () {
      final result = GlobalSearchService.filterVerses(verses, 'amou o mundo');
      expect(result.keys, contains('3'));
    });

    test('sem query retorna tudo', () {
      final result = GlobalSearchService.filterVerses(verses, '');
      expect(result.length, 2);
    });

    test('sem match retorna vazio', () {
      final result = GlobalSearchService.filterVerses(verses, 'zzzz');
      expect(result, isEmpty);
    });

    test('busca por numero do versiculo', () {
      final result = GlobalSearchService.filterVerses(verses, '16');
      expect(result.keys, contains('16'));
    });

    test('filtra intervalo de versos do capítulo: 1-3', () {
      const chapter = {
        '1': 'Primeiro verso',
        '2': 'Segundo verso',
        '3': 'Terceiro verso',
        '4': 'Quarto verso',
      };
      final result = GlobalSearchService.filterVerses(chapter, '1-3');
      expect(result.keys, ['1', '2', '3']);
    });

    test('filtra versos avulsos e intervalos: 1,3-4', () {
      const chapter = {
        '1': 'Primeiro verso',
        '2': 'Segundo verso',
        '3': 'Terceiro verso',
        '4': 'Quarto verso',
        '5': 'Quinto verso',
      };
      final result = GlobalSearchService.filterVerses(chapter, '1,3-4');
      expect(result.keys, ['1', '3', '4']);
    });

    test('range invertido normaliza: 3-1', () {
      const chapter = {'1': 'um', '2': 'dois', '3': 'três'};
      final result = GlobalSearchService.filterVerses(chapter, '3-1');
      expect(result.keys, ['1', '2', '3']);
    });
  });
}
