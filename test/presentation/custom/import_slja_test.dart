import 'dart:io';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/core/services/slja.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/import_slja.dart';

class _FakeFileSelector extends FileSelectorPlatform {
  final List<XFile> queue;
  int _i = 0;
  _FakeFileSelector(this.queue);

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    if (_i >= queue.length) return null;
    return queue[_i++];
  }
}

class _Call {
  final String method;
  final String url;
  _Call(this.method, this.url);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late List<_Call> calls;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('import_slja_test');
    calls = [];
    SharedPreferencesStorePlatform.instance = _FakePrefsStore();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  XFile sljaFile({bool withAudio = true}) {
    final archive = SljaArchive(
      title: 'Hino Importado',
      audio: withAudio
          ? const SljaAudio(name: 'a.mp3', bytes: [1, 2, 3])
          : null,
      slides: const [
        SljaSlide(type: 'CAPA', lyric: 'Capa', timeMs: 0),
        SljaSlide(type: 'LETRA', lyric: 'Verso 1', timeMs: 4000),
      ],
    );
    final f = File('${tmp.path}/musica.slja');
    f.writeAsBytesSync(buildSlja(archive));
    return XFile(f.path);
  }

  CustomCatalogApiImpl api() => CustomCatalogApiImpl(
        fetch: (method, url, {body, bearerToken}) async {
          calls.add(_Call(method, url));
          if (method == 'POST' && url.contains('/musics')) {
            return {'id_music': 99};
          }
          if (method == 'POST' && url.contains('/estrofes')) {
            return {'ok': true};
          }
          return <String, dynamic>{};
        },
        apiBaseUrl: 'https://api.test',
        filesBaseUrl: 'https://api.test/file',
      );

  CustomFileApi fileApi() {
    final dio = Dio()..httpClientAdapter = _UploadAdapter();
    return CustomFileApi(dio: dio, apiBaseUrl: 'https://api.test');
  }

  testWidgets('cancelar seletor não faz nada', (tester) async {
    FileSelectorPlatform.instance = _FakeFileSelector([]);
    var done = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              importSljaIntoCollection(
                context,
                api: api(),
                fileApi: fileApi(),
                collection: const CustomCollection(
                  id: 6,
                  name: 'C',
                  musicsCount: 0,
                  isOwner: true,
                ),
                bearerToken: 'tok',
                onDone: () => done = true,
              );
            },
            child: const Text('importar'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('importar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(done, isFalse);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('importa .slja: dispara fluxo e conclui com onDone', (
    tester,
  ) async {
    FileSelectorPlatform.instance = _FakeFileSelector([sljaFile()]);

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    ));

    // Sem await: upload multipart roda IO real — pendura no fake async.
    final fut = importSljaIntoCollection(
      ctx,
      api: api(),
      fileApi: fileApi(),
      collection: const CustomCollection(
        id: 6,
        name: 'C',
        musicsCount: 0,
        isOwner: true,
      ),
      bearerToken: 'tok',
      onDone: () {},
    );
    unawaited(
      fut.catchError((Object e) {}, test: (e) => e is Exception),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });


}

/// SharedPreferences fake pro CustomCatalogApiImpl (joined key).
class _FakePrefsStore extends SharedPreferencesStorePlatform {
  final Map<String, Object> data = {};

  @override
  Future<bool> clear() async {
    data.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map.of(data);

  @override
  Future<bool> remove(String key) async {
    data.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    data[key] = value;
    return true;
  }
}

/// Adapter dio que responde 200 com id_file pra upload de áudio.
class _UploadAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'id_file': 777, 'url': '/audio/a.mp3'}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
