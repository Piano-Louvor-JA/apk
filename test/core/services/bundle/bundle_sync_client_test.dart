library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_snapshot_store.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_client.dart';
import 'package:louvorja_piano_mobile/core/services/bundle/bundle_sync_contract.dart';

import '../../../helpers/bundle_fixture_builder.dart' as helper;

final _fixtureDir = Directory('test/fixtures/bundle');

dynamic _readJson(String name) =>
    jsonDecode(File('${_fixtureDir.path}/$name').readAsStringSync());

class _CountingAdapter implements HttpClientAdapter {
  final List<_Recorded> requests = [];
  final _Respond responder;

  _CountingAdapter(this.responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    requests.add(_Recorded(path, options.headers));
    return responder(options);
  }
}

class _Recorded {
  final String path;
  final Map<String, dynamic> headers;
  _Recorded(this.path, this.headers);
}

typedef _Respond = Future<ResponseBody> Function(RequestOptions options);

ResponseBody _jsonBody(dynamic data) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
  return ResponseBody(
    Stream.fromIterable([bytes]),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

ResponseBody _zipBody(List<int> bytes) {
  return ResponseBody(
    Stream.fromIterable([Uint8List.fromList(bytes)]),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/zip'],
    },
  );
}

void main() {
  late Directory tmp;
  late Directory stateDir;
  late BundleSnapshotStore store;
  late File stateFile;
  late _CountingAdapter adapter;
  late Dio dio;
  late int nowMs;
  late BundleSyncClient client;

  List<Map<String, dynamic>> realEntries() =>
      (_readJson('manifest_real_entries.json') as List)
          .cast<Map<String, dynamic>>();

  BundleSyncClient makeClient() => BundleSyncClient(
        dio: dio,
        origin: 'https://bundles.example.com',
        store: store,
        stateFile: stateFile,
        now: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bundle_client_test');
    stateDir = Directory('${tmp.path}/state')..createSync(recursive: true);
    store = BundleSnapshotStore(Directory('${tmp.path}/snap'));
    stateFile = File('${stateDir.path}/bundle_sync_state.json');
    nowMs = 1730000000000;
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('cold sync: 1 manifest + 2 ZIPs (ambos divergentes) e aplica tudo (RF-21)',
      () async {
    final zips = {
      '/db/catalog-bundle': helper.buildBundleZip(BundleKind.catalog, [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        'album_1.json',
      ]),
      '/db/bible-bundle': helper.buildBundleZip(BundleKind.bible, [
        'bible_10_100_1.json',
        'bible_10_100_2.json',
        'bible_10_100_3.json',
      ]),
    };
    adapter = _CountingAdapter((req) async {
      if (req.uri.path == '/db/manifest') {
        return _jsonBody(realEntries());
      }
      return _zipBody(zips[req.uri.path]!);
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();

    final result = await client.checkForUpdates();
    expect(result.ok, isTrue);
    expect(result.checked, containsAll(['catalog', 'bible']));
    expect(result.applied, containsAll(['catalog', 'bible']));
    expect(
      adapter.requests.map((r) => r.path).toList(),
      ['/db/manifest', '/db/catalog-bundle', '/db/bible-bundle'],
    );
    // snapshots aplicados
    expect(store.readJson(BundleKind.catalog, 'config'), isNotNull);
    expect(store.readJson(BundleKind.bible, 'bible_10_100_1'), isNotNull);
    // estado gravado SOMENTE após aplicação
    final state = BundleArtifactState.fromJson(
      BundleKind.catalog,
      jsonDecode(stateFile.readAsStringSync())['catalog']
          as Map<String, dynamic>,
    );
    expect(state!.appliedAtEpochMs, nowMs);
  });

  test('run <24h: 0 requests (RF-20)', () async {
    var calls = 0;
    adapter = _CountingAdapter((req) async {
      calls++;
      return _jsonBody(realEntries());
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    await client.checkForUpdates(); // cold (falha nos ZIPs é tolerada)

    nowMs += 12 * 60 * 60 * 1000; // 12h depois
    final before = adapter.requests.length;
    final result = await client.checkForUpdates();
    expect(result.ok, isTrue);
    expect(result.checked, isEmpty);
    expect(adapter.requests.length, before);
    expect(calls, greaterThanOrEqualTo(1));
  });

  test('≥24h com digest igual: 1 manifest, 0 ZIP, só checkedAt (RF-20/RED 2)',
      () async {
    final zips = {
      '/db/catalog-bundle': helper.buildBundleZip(BundleKind.catalog, [
        'config.json',
        'pt_categories.json',
        'pt_musics.json',
        'album_1.json',
      ]),
      '/db/bible-bundle': helper.buildBundleZip(BundleKind.bible, [
        'bible_10_100_1.json',
        'bible_10_100_2.json',
        'bible_10_100_3.json',
      ]),
    };
    adapter = _CountingAdapter((req) async {
      if (req.uri.path == '/db/manifest') {
        return _jsonBody(realEntries());
      }
      return _zipBody(zips[req.uri.path]!);
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    await client.checkForUpdates(); // aplica

    nowMs += 25 * 60 * 60 * 1000; // 25h depois
    adapter.requests.clear();
    final result = await client.checkForUpdates();
    expect(result.ok, isTrue);
    expect(result.checked, isNotEmpty);
    expect(result.applied, isEmpty);
    expect(adapter.requests.map((r) => r.path), ['/db/manifest']);
    final state = BundleArtifactState.fromJson(
      BundleKind.catalog,
      jsonDecode(stateFile.readAsStringSync())['catalog']
          as Map<String, dynamic>,
    );
    expect(state!.checkedAtEpochMs, nowMs);
    expect(state.appliedAtEpochMs, isNot(nowMs)); // aplicação antiga preservada
  });

  test('manifest inválido → sync aborta, 0 ZIP, cache intacto (RF-19/RED 1)',
      () async {
    adapter = _CountingAdapter((req) async {
      if (req.uri.path == '/db/manifest') {
        return _jsonBody({'schema': 1, 'artifacts': {}}); // envelope antigo
      }
      fail('nenhum ZIP deve ser requisitado com manifest inválido');
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    await store.commit(BundleKind.catalog, {'config': '{"v":1}'});

    final result = await client.checkForUpdates();
    expect(result.ok, isFalse);
    expect(adapter.requests.map((r) => r.path), ['/db/manifest']);
    expect(store.readJson(BundleKind.catalog, 'config'), {'v': 1});
  });

  test('ZIP com MD5 divergente: NADA aplicado, estado antigo preservado (RED 3/7)',
      () async {
    final goodZip = helper.buildBundleZip(BundleKind.catalog, [
      'config.json',
      'pt_categories.json',
      'pt_musics.json',
      'album_1.json',
    ]);
    final tampered = helper.buildBundleZip(
      BundleKind.catalog,
      ['config.json', 'pt_categories.json', 'pt_musics.json', 'album_1.json'],
      overrideFiles: {'pt_musics.json': utf8.encode('[]')},
    );
    var call = 0;
    adapter = _CountingAdapter((req) async {
      if (req.uri.path == '/db/manifest') {
        return _jsonBody(realEntries());
      }
      call++;
      return _zipBody(call == 1 ? goodZip : tampered);
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    final first = await client.checkForUpdates();
    expect(first.applied, contains('catalog'));

    // muda o estado do manifest (novo hash) para forçar download
    final entries = realEntries()
      ..first['hash'] = '115b3ef31c499af129e3de5a55e56270';
    nowMs += 25 * 60 * 60 * 1000;
    adapter = _CountingAdapter((req) async {
      if (req.uri.path == '/db/manifest') {
        return _jsonBody(entries);
      }
      return _zipBody(tampered);
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    final second = await client.checkForUpdates();
    expect(second.ok, isFalse);
    // snapshot antigo continua íntegro
    expect(store.readJson(BundleKind.catalog, 'config'), isNotNull);
  });

  test('429 no manifest: mantém cache, registra tentativa, sem retry <24h (ADR-03)',
      () async {
    adapter = _CountingAdapter((req) async {
      throw DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: 429),
      );
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    final result = await client.checkForUpdates();
    expect(result.ok, isFalse);

    // estado com digest vazio registra a tentativa (inibe retry)
    final raw = jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
    expect(raw['catalog']['manifestDigest'], '');

    nowMs += 12 * 60 * 60 * 1000;
    adapter.requests.clear();
    final again = await client.checkForUpdates();
    expect(again.checked, isEmpty); // bloqueado <24h
  });

  test('RED 8: nenhum request usa path do payload; origem só da env', () async {
    adapter = _CountingAdapter((req) async {
      expect(req.uri.origin, 'https://bundles.example.com');
      if (req.uri.path == '/db/manifest') {
        return _jsonBody(realEntries());
      }
      if (req.uri.path == '/db/catalog-bundle') {
        return _zipBody(helper.buildBundleZip(BundleKind.catalog, [
          'config.json',
          'pt_categories.json',
          'pt_musics.json',
          'album_1.json',
        ]));
      }
      return _zipBody(helper.buildBundleZip(BundleKind.bible, [
        'bible_10_100_1.json',
        'bible_10_100_2.json',
        'bible_10_100_3.json',
      ]));
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    final result = await client.checkForUpdates();
    expect(result.ok, isTrue);
    expect(
      adapter.requests.map((r) => r.path).toSet(),
      {'/db/manifest', '/db/catalog-bundle', '/db/bible-bundle'},
    );
  });

  test('force ignora a janela de 24h (ação manual)', () async {
    adapter = _CountingAdapter((req) async {
      if (req.uri.path == '/db/manifest') {
        return _jsonBody(realEntries());
      }
      // ZIPs: content-type json (não zip) — falha controlada, sem aplicar.
      return _jsonBody({'noop': true});
    });
    dio = Dio();
    dio.httpClientAdapter = adapter;
    client = makeClient();
    await client.checkForUpdates();
    adapter.requests.clear();
    final result = await client.checkForUpdates(force: true);
    expect(result.checked, isNotEmpty);
    // 1 manifest re-validado; ZIPs tentados 1x cada e falham sem aplicar.
    expect(
      adapter.requests.map((r) => r.path).toList(),
      ['/db/manifest', '/db/catalog-bundle', '/db/bible-bundle'],
    );
    // Segundo force: manifest de novo (estado de falha não inibe força).
    adapter.requests.clear();
    final again = await client.checkForUpdates(force: true);
    expect(again.checked, isNotEmpty);
    expect(adapter.requests.first.path, '/db/manifest');
  });
}
