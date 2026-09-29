import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_catalog_api_impl.dart';

/// E2E de ponta a ponta contra a API REAL (http://192.168.1.192:3100).
/// Fluxo completo: registrar → criar coletânea → criar música → upload
/// áudio/BG → estrofes com timing e BG → GET detail → permissões de
/// terceiro (is_owner=0, escrita 401) → cleanup (delete música/coletânea).
///
/// PULA automaticamente se a API local não estiver acessível — roda
/// `dart test test/e2e` com a piano-api de dev no ar.
void main() {
  const apiBase = 'http://192.168.1.192:3100';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'e2e_$stamp@teste.com';

  String? token;
  late CustomCatalogApiImpl api;

  setUpAll(() async {
    try {
      final ping = await http
          .get(Uri.parse('$apiBase/v1/custom/collections'))
          .timeout(const Duration(seconds: 3));
      if (ping.statusCode != 200) throw Exception('offline');
    } catch (_) {
      print('--- API $apiBase inacessível: E2E pulado ---');
      return;
    }

    final reg = await http.post(
      Uri.parse('$apiBase/v1/custom/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': 'E2e12345!',
        'displayName': 'E2E $stamp',
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
  });

  test(
    'E2E: coletânea → música → uploads → estrofes → permissões → delete',
    () async {
      final tok = token;
      if (tok == null || tok.isEmpty) {
        print('--- API offline: teste pulado ---');
        return;
      }

      // 1. criar coletânea
      final collectionId = await api.createCollection(
        name: 'E2E $stamp',
        authorName: 'E2E Bot',
        bearerToken: tok,
      );
      expect(collectionId, greaterThan(0));

      // 2. listagem marca como dono
      final collections = await api.fetchCollections(bearerToken: tok);
      final mine = collections.firstWhere((c) => c.id == collectionId);
      expect(mine.isOwner, isTrue);

      // 3. upload áudio + BG ANTES da música (áudio entra na criação)
      final audioBytes = List<int>.filled(2048, 1);
      final audioUpload = await _uploadFile(
        apiBase,
        tok,
        audioBytes,
        'e2e_$stamp.mp3',
        'audio/mpeg',
        'audio',
      );
      expect(audioUpload['id_file'] as int, greaterThan(0));
      final audioId = audioUpload['id_file'] as int;

      final musicId = await api.createMusic(
        collectionId: collectionId,
        name: 'E2E Música $stamp',
        idFileAudio: audioId,
        bearerToken: tok,
      );
      expect(musicId, greaterThan(0));

      final pngBytes = <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        ...List<int>.filled(512, 2),
      ];
      final bgUpload = await _uploadFile(
        apiBase,
        tok,
        pngBytes,
        'e2e_$stamp.png',
        'image/png',
        'imagens',
      );
      final bgId = bgUpload['id_file'] as int;

      // 5. estrofes: capa com BG + 2 com timing
      await api.addLyric(
        musicId: musicId,
        lyric: 'E2E CAPA',
        time: '00:00.000',
        order: 0,
        idFileImage: bgId,
        bearerToken: tok,
      );
      await api.addLyric(
        musicId: musicId,
        lyric: 'Primeira linha|Segunda linha',
        time: '00:05.000',
        order: 1,
        bearerToken: tok,
      );
      await api.addLyric(
        musicId: musicId,
        lyric: 'Terceira estrofe',
        time: '00:12.000',
        order: 2,
        bearerToken: tok,
      );

      // 6. áudio associado na criação — validar via detail abaixo

      // 7. GET detail: estrofes com timing, BG resolvido e audio_url
      final detail = await api.fetchMusicDetail(musicId);
      expect(detail.lyrics, hasLength(3));
      expect(detail.audioUrl, isNotNull);
      expect(
        detail.lyrics.first.imageUrl,
        isNotNull,
        reason: 'BG da capa deve vir resolvido',
      );
      final times = detail.lyrics.map((s) => s.time).toList();
      expect(times, everyElement(isNotNull));

      // 8. arquivo servido: cliente já resolve com filesBaseUrl → URL completa
      final audioGet = await http.get(Uri.parse(detail.audioUrl!));
      expect(audioGet.statusCode, 200, reason: detail.audioUrl);
      expect(audioGet.bodyBytes, hasLength(audioBytes.length));

      // 9. terceiro sem token: is_owner=0 e escrita 401
      final anon = await http.get(Uri.parse('$apiBase/v1/custom/collections'));
      final anonCols = (jsonDecode(anon.body)['data'] as List)
          .cast<Map<String, dynamic>>();
      final anonMine = anonCols.firstWhere(
        (c) => c['id_collection'] == collectionId,
      );
      expect(anonMine['is_owner'], 0);
      final hack = await http.put(
        Uri.parse('$apiBase/v1/custom/musics/$musicId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': 'HACK'}),
      );
      expect(hack.statusCode, 401);

      // 10. cleanup: dono apaga música (DELETE /musics/{id}) e coletânea
      await api.removeMusicFromCollection(musicId: musicId, bearerToken: tok);
      await api.deleteCollection(collectionId, bearerToken: tok);
      final after = await api.fetchCollections();
      expect(after.any((c) => c.id == collectionId), isFalse);
    },
  );
}

Future<Map<String, dynamic>> _uploadFile(
  String apiBase,
  String token,
  List<int> bytes,
  String filename,
  String mimeType,
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
