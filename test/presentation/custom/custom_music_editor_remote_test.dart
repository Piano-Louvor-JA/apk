library;

import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';
import 'package:dio/dio.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_collection.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_music_editor_page.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Onda 81: fluxo REMOTO do editor (bearer != null) — upload de áudio,
/// createMusic, addLyric por estrofe, snack de sucesso e detail SEM áudio
/// (não navega pro recorder, só pop) + falha de save com snack de erro.
class _QueuePicker extends FileSelectorPlatform {
  final List<XFile> queue;
  int _i = 0;
  _QueuePicker(this.queue);

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => _i < queue.length ? queue[_i++] : null;
}

const _collection = CustomCollection(
  id: 3,
  name: 'Coletânea Remota',
  musicsCount: 0,
  isOwner: true,
);

// _fetch: rota → resposta. POST files → id_file; POST musics → id_music;
// POST lyrics → id_lyric; GET detail → música SEM audio_url (pop direto).
int apiCalls = 0;
List<String> apiRoutes = [];

class _UploadAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({'id_file': 55, 'url': '/audio/a.mp3'}),
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
}

CustomCatalogApiImpl _api() => CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        apiCalls++;
        apiRoutes.add('$method $url');
        if (url.contains('/v1/custom/files')) {
          return {'id_file': 55};
        }
        if (method == 'POST' && RegExp(r'/musics$').hasMatch(url)) {
          return {'id_music': 77};
        }
        if (RegExp(r'/lyrics$').hasMatch(url)) {
          return {'id_lyric': 1};
        }
        if (method == 'GET' && url.contains('/musics/77')) {
          return {
            'id_music': 77,
            'name': 'Hino Remoto',
            'lyrics': [
              {'id_lyric': 1, 'lyric': 'E1', 'order': 0, 'time': '00:00.000'},
              {'id_lyric': 2, 'lyric': 'E2', 'order': 1, 'time': '00:00.000'},
            ],
            // sem audio_url → não abre recorder
          };
        }
        throw Exception('rota não mockada: $method $url');
      },
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );

CustomCatalogApiImpl _apiFail() => CustomCatalogApiImpl(
      fetch: (m, u, {body, bearerToken}) async => throw Exception('503'),
      apiBaseUrl: 'https://api.test',
      filesBaseUrl: 'https://api.test/file',
    );

Widget _editor(CustomCatalogApiImpl api, {String? fileBase}) => MaterialApp(
      home: CustomMusicEditorPage(
        api: api,
        fileApi: CustomFileApi(
          dio: Dio()..httpClientAdapter = _UploadAdapter(),
          apiBaseUrl: fileBase ?? 'https://api.test',
        ),
        collection: _collection,
        bearerToken: 'tok',
      ),
    );

Future<void> _fill(WidgetTester tester, Widget w, String audioPath) async {
  await tester.pumpWidget(w);
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(0), 'Hino Remoto');
  await tester.enterText(find.byType(TextField).at(1), 'E1\n\nE2');
  await tester.tap(find.text('Escolher áudio (obrigatório) *'));
  await tester.pump();
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('editor_remote_test');
    final audio = File('${tmp.path}/audio.mp3')..writeAsStringSync('audio');
    FileSelectorPlatform.instance = _QueuePicker([XFile(audio.path)]);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  testWidgets('fluxo remoto: upload áudio, cria música, 2 estrofes, pop', (
    tester,
  ) async {
    await _fill(tester, _editor(_api()), '${tmp.path}/audio.mp3');

    await tester.tap(find.text('Salvar'), warnIfMissed: false);
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(apiCalls, 4);
    expect(apiRoutes.where((r) => r.contains('/lyrics')).length, 2);
    // ignore: avoid_print
    // fluxo completo executado: create + 2 lyrics + detail
    expect(apiRoutes.where((r) => r.contains('/lyrics')).length, 2);
    expect(apiRoutes.any((r) => r.contains('GET') && r.contains('/musics/77')), isTrue);
    // detail sem audio_url → pop (editor saiu da árvore)
    expect(find.text('Escolher áudio (obrigatório) *'), findsNothing);
    expect(find.text('Nova música'), findsNothing);
  });

  testWidgets('falha remota: snack de erro e continua na página', (
    tester,
  ) async {
    await _fill(tester, _editor(_apiFail()), '${tmp.path}/audio.mp3');

    await tester.tap(find.text('Salvar'), warnIfMissed: false);
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Falha ao salvar'), findsOneWidget);
    // continua na página: áudio ainda escolhido e título presente
    expect(find.textContaining('Áudio: audio.mp3'), findsOneWidget);
    expect(find.text('Nova música'), findsOneWidget);
  });
}
