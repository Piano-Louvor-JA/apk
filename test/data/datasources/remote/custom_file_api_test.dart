import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_file_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upload monta multipart com kind e Bearer, parseia resposta', () async {
    RequestInfo? captured;
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, body) {
        captured = RequestInfo(
          method: options.method,
          url: options.uri.toString(),
          auth: options.headers['Authorization']?.toString(),
          contentType: options.headers[Headers.contentTypeHeader]?.toString(),
          body: body,
        );
        return '{"id_file": 42, "url": "/custom/audio/musica.mp3", "name": "musica.mp3", "size": 1024}';
      });

    final api = CustomFileApi(dio: dio, apiBaseUrl: 'https://api.test');

    final tmp = File(
      '${Directory.systemTemp.path}/custom_file_test_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    tmp.writeAsBytesSync(List.filled(64, 7));

    final result = await api.upload(tmp, kind: 'audio', bearerToken: 'tok');

    expect(result.idFile, 42);
    expect(result.url, '/custom/audio/musica.mp3');
    expect(captured!.method, 'POST');
    expect(captured!.url, 'https://api.test/v1/custom/files');
    expect(captured!.auth, 'Bearer tok');
    expect(
      captured!.body,
      isNotEmpty,
      reason: 'multipart tem corpo (arquivo + campos)',
    );
    expect(captured!.auth, 'Bearer tok');
    tmp.deleteSync();
  });
}

class RequestInfo {
  final String method;
  final String url;
  final String? auth;
  final String? contentType;
  final String body;
  RequestInfo({
    required this.method,
    required this.url,
    this.auth,
    this.contentType,
    required this.body,
  });
}

/// Adapter de captura: devolve o corpo como string pro teste inspecionar.
class _CaptureAdapter implements HttpClientAdapter {
  final String Function(RequestOptions options, String body) _responder;
  _CaptureAdapter(this._responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Multipart: requestStream vem como stream de bytes do form-data.
    final chunks = <int>[];
    if (requestStream != null) {
      await for (final c in requestStream) {
        chunks.addAll(c);
      }
    }
    final body = String.fromCharCodes(chunks);
    return ResponseBody.fromString(
      _responder(options, body),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
