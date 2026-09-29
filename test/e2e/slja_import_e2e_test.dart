import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:louvorja_piano_mobile/core/services/slja.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';

/// E2E de IMPORT .slja contra a API REAL (http://192.168.1.192:3100):
/// registra conta → cria coletânea → constrói .slja.zip de fixture
/// Delphi → importa (upload áudio + música + estrofes com tempo_hms) →
/// valida o GET detail (estrofes com timing, áudio associado) → cleanup.
///
/// Pula sozinho se a API local não estiver acessível.
void main() {
  const apiBase = 'http://192.168.1.192:3100';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'slja_e2e_$stamp@teste.com';

  String? token;
  late CustomCatalogApiImpl api;
  int? collectionId;

  setUpAll(() async {
    try {
      final ping = await http
          .get(Uri.parse('$apiBase/v1/custom/collections'))
          .timeout(const Duration(seconds: 3));
      if (ping.statusCode != 200) throw Exception('offline');
    } catch (_) {
      print('--- API $apiBase inacessível: E2E .slja pulado ---');
      return;
    }

    final reg = await http.post(
      Uri.parse('$apiBase/v1/custom/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': 'E2e12345!',
        'displayName': 'SLJA $stamp',
      }),
    );
    expect(reg.statusCode, anyOf(200, 201), reason: reg.body);
    token = (jsonDecode(reg.body) as Map<String, dynamic>)['token'] as String;

    api = CustomCatalogApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        final uri = Uri.parse(url.startsWith('http') ? url : '$apiBase$url');
        final request = http.Request(method, uri)
          ..headers['Content-Type'] = 'application/json';
        if (bearerToken != null) {
          request.headers['Authorization'] = 'Bearer $bearerToken';
        }
        if (body != null) request.body = jsonEncode(body);
        final response = await http.Response.fromStream(await request.send());
        return jsonDecode(response.body) as Map<String, dynamic>;
      },
      apiBaseUrl: apiBase,
      filesBaseUrl: '$apiBase/file',
    );

    collectionId = await api.createCollection(
      name: 'SLJA E2E $stamp',
      authorName: 'SLJA Bot',
      bearerToken: token!,
    );
  });

  test(
    'E2E: .slja.zip → upload áudio → música → estrofes com timing',
    () async {
      final tok = token;
      if (tok == null || tok.isEmpty) {
        print('--- API offline: teste pulado ---');
        return;
      }
      final colId = collectionId!;

      // 1. fixture .slja.zip (wrapper de WhatsApp: zip contendo o .slja)
      final ini =
          '''
[Geral]
slides=3
versao=2.0
titulo=E2E Importada $stamp
audio=1
url_musica=audio\\\\e2e.mp3

[Slide:1]
tipo=CAPA
letra=E2E IMPORTADA

[Slide:2]
tipo=LETRA
letra=Primeira linha do import|Segunda linha
tempo_hms=00:00:10

[Slide:3]
tipo=LETRA
letra=Ultima estrofe
tempo_hms=00:00:25
''';
      // .slja = ZIP contendo slides.lja (formato Delphi)
      final innerSlja = ZipEncoder().encode(
        Archive()..addFile(ArchiveFile.bytes('slides.lja', latin1.encode(ini))),
      );
      // WhatsApp anexa .zip na extensão: o arquivo vira 'nome.slja.zip',
      // que continua sendo o MESMO zip interno (slides.lja dentro).
      final wrapperZip = innerSlja;

      final archive = parseSlja(wrapperZip);
      expect(archive.title, 'E2E Importada $stamp');
      final lyricSlides = archive.slides
          .where((s) => s.type != 'CAPA')
          .toList();
      expect(lyricSlides, hasLength(2));

      // 2. upload do áudio embutido
      final audioBytes = List<int>.filled(1024, 7);
      final upload = await _upload(
        apiBase,
        tok,
        audioBytes,
        'e2e_$stamp.mp3',
        'audio',
      );
      final audioId = upload['id_file'] as int;

      // 3. criar música + estrofes com tempo (mesma sequência do import)
      final musicId = await api.createMusic(
        collectionId: colId,
        name: archive.title,
        idFileAudio: audioId,
        bearerToken: tok,
      );
      // ignore: avoid_print
      print('DBG colId=$colId musicId=$musicId');
      expect(musicId, greaterThan(0));

      for (var i = 0; i < lyricSlides.length; i++) {
        final s = lyricSlides[i];
        await api.addLyric(
          musicId: musicId,
          lyric: s.lyric,
          auxLyric: s.auxiliaryLyric,
          time: s.timeMs > 0 ? _msToDbTime(s.timeMs) : '00:00.000',
          order: i,
          bearerToken: tok,
        );
      }

      // 4. valida GET detail: 2 estrofes com timing real + áudio
      final detail = await api.fetchMusicDetail(musicId);
      expect(detail.lyrics, hasLength(2));
      expect(detail.audioUrl, isNotNull);
      expect(detail.lyrics[0].time, '00:10.000');
      expect(detail.lyrics[1].time, '00:25.000');
      expect(detail.lyrics[0].text, contains('Primeira linha'));

      // 5. cleanup
      await api.removeMusicFromCollection(musicId: musicId, bearerToken: tok);
      await api.deleteCollection(colId, bearerToken: tok);
    },
  );

  tearDownAll(() async {
    final tok = token;
    if (tok != null && tok.isNotEmpty && collectionId != null) {
      try {
        await http.delete(
          Uri.parse('$apiBase/v1/custom/collections/$collectionId'),
          headers: {'Authorization': 'Bearer $tok'},
        );
      } catch (_) {}
    }
  });
}

Future<Map<String, dynamic>> _upload(
  String apiBase,
  String token,
  List<int> bytes,
  String filename,
  String kind,
) async {
  final request =
      http.MultipartRequest('POST', Uri.parse('$apiBase/v1/custom/files'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        )
        ..fields['kind'] = kind;
  final response = await http.Response.fromStream(await request.send());
  expect(response.statusCode, anyOf(200, 201), reason: response.body);
  return jsonDecode(response.body) as Map<String, dynamic>;
}

String _msToDbTime(int ms) {
  final mm = (ms ~/ 60000).toString().padLeft(2, '0');
  final ss = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
  final mmm = (ms % 1000).toString().padLeft(3, '0');
  return '$mm:$ss.$mmm';
}
