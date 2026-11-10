library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_snapshot_store.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';


final _fixtureDir = Directory('test/fixtures/bundle');

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) responder;
  _Adapter(this.responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responder(options);
  }
}

void main() {
  test('RF-22/ADR-11: urlBundles usa LOUVORJA_URL_BUNDLES com default público upstream',
      () {
    // Default (sem dart-define): upstream público documentado.
    expect(ApiConfig.defaultBundlesOrigin, 'https://api.louvorja.com.br');
    expect(ApiConfig.bundlesUrls(), [
      'https://api.louvorja.com.br',
    ]);
  });

  test('bundles NUNCA derivam de urlDatabase (separação ADR-11)', () {
    // urlDatabase aponta /json_db da nossa API; /db/* não existe lá.
    // bundlesUrls() deve ignorá-la por completo.
    expect(
      ApiConfig.bundlesUrls().where((u) => u.contains('json_db')),
      isEmpty,
    );
    expect(
      ApiConfig.bundlesUrls().where((u) => u.contains('pianolouvorja')),
      isEmpty,
    );
  });

  group('bundle-first no LouvorjaApiImpl (RF-03/RF-04)', () {
    late Directory tmp;
    late BundleSnapshotStore store;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('api_bundle_test');
      store = BundleSnapshotStore(Directory('${tmp.path}/snap'));
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    Future<void> seedBundles() async {
      await store.commit(BundleKind.catalog, {
        'config': File('${_fixtureDir.path}/real_config.json')
            .readAsStringSync(),
        'pt_categories': File('${_fixtureDir.path}/real_pt_categories.json')
            .readAsStringSync(),
        'pt_musics': File('${_fixtureDir.path}/real_pt_musics.json')
            .readAsStringSync(),
        'album_1': File('${_fixtureDir.path}/real_album_1.json')
            .readAsStringSync(),
      });
      await store.commit(BundleKind.bible, {
        'bible_10_100_1': File('${_fixtureDir.path}/real_bible_10_100_1.json')
            .readAsStringSync(),
        'bible_10_100_2': File('${_fixtureDir.path}/real_bible_10_100_2.json')
            .readAsStringSync(),
      });
    }

    LouvorjaApiImpl makeApi(_Adapter adapter) {
      final api = LouvorjaApiImpl.single(
        baseUrl: 'https://api.example.com/json_db',
        filesUrl: 'https://api.example.com/file',
        apiToken: 'token',
        bundleStore: store,
      );
      api.dio.httpClientAdapter = adapter;
      return api;
    }

    test('chave do bundle aplicado serve SEM request (RF-03/RF-04)', () async {
      await seedBundles();
      var networkCalls = 0;
      final api = makeApi(_Adapter((req) async {
        networkCalls++;
        throw DioException(requestOptions: req);
      }));

      final categories = await api.fetchCategories();
      expect(categories, isNotEmpty);
      final musics = await api.fetchMusicIndex();
      expect(musics.length, 1889); // pt_musics real tem 1889 entries
      final hymns = await api.fetchAlbumHymns(1);
      expect(hymns, isA<List<dynamic>>());
      final chapter = await api.fetchBibleChapter(10, 100, 1);
      expect(chapter, isNotEmpty);
      expect(networkCalls, 0,
          reason: 'bundle-first: 0 requests com snapshot aplicado');
    });

    test('chave AUSENTE do bundle cai no fluxo legado (fallback RF-06)', () async {
      await seedBundles();
      var legacyCalls = 0;
      final api = makeApi(_Adapter((req) async {
        legacyCalls++;
        // music_<id> retorna um OBJETO hino (shape do endpoint real).
        final body = Uint8List.fromList(utf8.encode(
            '{"id_music":7,"name":"Hino 7","track":1}'));
        return ResponseBody(Stream.fromIterable([body]), 200, headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
      }));

      // music_999999 não está no snapshot → legado item-a-item
      final hymn = await api.fetchMusic(999999);
      expect(hymn.id, 7);
      expect(legacyCalls, 1);
      expect(
        legacyCalls == 1,
        isTrue,
        reason: 'exatamente 1 request do dado ausente, sem varredura',
      );
    });
  });
}
