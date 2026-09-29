library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/offline_library_filter.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/domain/entities/album.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';

class _LibraryOffline implements OfflineMusicPort, OfflineLibraryPort {
  final List<OfflineListedTrack> tracks;
  _LibraryOffline(this.tracks);

  @override
  Future<List<OfflineListedTrack>> listDownloaded({int? albumId}) async =>
      tracks.where((t) => albumId == null || t.albumId == albumId).toList();

  @override
  bool get isSupported => true;

  @override
  noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  test('offline: home mostra apenas álbuns com faixas baixadas', () async {
    final offline = _LibraryOffline([
      const OfflineListedTrack(
        musicId: 10,
        path: '/local/10.mp3',
        title: 'Hino 10',
        albumId: 100,
        albumName: 'Louvor JA 2026',
      ),
      const OfflineListedTrack(
        musicId: 11,
        path: '/local/11.mp3',
        title: 'Hino 11',
        albumId: 100,
      ),
    ]);

    final categories = [
      const AlbumCategory(
        id: 1,
        name: 'Coletâneas',
        albums: [
          Album(id: 100, name: 'Louvor JA 2026'),
          Album(id: 200, name: 'Vozes Femininas'), // sem downloads
        ],
      ),
      const AlbumCategory(
        id: 2,
        name: 'Vazia',
        albums: [Album(id: 300, name: 'Nada baixado')],
      ),
    ];

    final filtered = await OfflineLibraryFilter.filterCategories(
      categories: categories,
      offline: offline,
    );

    expect(filtered, hasLength(1), reason: 'só a categoria com downloads');
    expect(filtered.first.albums, hasLength(1));
    expect(filtered.first.albums.first.id, 100);
    expect(filtered.first.albums.first.trackCount, 2);
    expect(filtered.first.albums.first.subtitle, contains('baixadas'));
  });

  test('offline: detalhe do álbum lista somente faixas baixadas', () async {
    final offline = _LibraryOffline([
      const OfflineListedTrack(
        musicId: 10,
        path: '/local/10.mp3',
        title: 'Nosso Sol é Jesus',
        number: '001',
        albumId: 100,
      ),
    ]);

    final hymns = await OfflineLibraryFilter.hymnsForAlbum(
      albumId: 100,
      offline: offline,
    );

    expect(hymns, isNotNull);
    expect(hymns!.single.title, 'Nosso Sol é Jesus');
    expect(hymns.single.number, 1);
  });

  test('sem biblioteca (port antigo): mantém catálogo do cache', () async {
    final offline = _NoLibraryOffline();
    final categories = const [
      AlbumCategory(
        id: 1,
        name: 'Cat',
        albums: [Album(id: 1, name: 'A')],
      ),
    ];
    final filtered = await OfflineLibraryFilter.filterCategories(
      categories: categories,
      offline: offline,
    );
    expect(filtered, same(categories));
  });
}

class _NoLibraryOffline implements OfflineMusicPort {
  @override
  bool get isSupported => true;

  @override
  noSuchMethod(Invocation i) => throw UnimplementedError();
}
