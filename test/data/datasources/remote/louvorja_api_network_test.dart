library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';

/// Mock adapter que retorna JSON pre-configurado.
class _MockAdapter implements HttpClientAdapter {
  final dynamic Function(RequestOptions) responder;

  _MockAdapter(this.responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = responder(options);
    if (result is int && result >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: result),
        type: DioExceptionType.badResponse,
      );
    }
    final json = result is String ? result : '{"data":true}';
    final bytes = Uint8List.fromList(json.codeUnits);
    return ResponseBody(
      Stream.fromIterable([bytes]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  LouvorjaApiImpl createApi(_MockAdapter adapter) {
    final api = LouvorjaApiImpl.single(
      baseUrl: 'https://api.example.com/json_db',
      filesUrl: 'https://api.example.com/file',
      apiToken: 'token',
      languagePrefix: 'pt',
      now: () => DateTime(2026, 8, 10),
    );
    api.dio.httpClientAdapter = adapter;
    return api;
  }

  test('fetchCategories retorna lista parseada', () async {
    final api = createApi(
      _MockAdapter((req) {
        return '[{"id_category":1,"name":"Cat","albums":[]}]';
      }),
    );

    final result = await api.fetchCategories();
    expect(result.length, 1);
    expect(result[0].name, 'Cat');
  });

  test('fetchAlbumHymns retorna hinos parseados', () async {
    final api = createApi(
      _MockAdapter((req) {
        return '{"musics":[{"id_music":1,"name":"Hino 1","track":1}]}';
      }),
    );

    final result = await api.fetchAlbumHymns(100);
    expect(result.length, 1);
    expect(result[0].title, 'Hino 1');
  });

  test('fetchAlbumHymns com musics vazio retorna lista vazia', () async {
    final api = createApi(_MockAdapter((req) => '{}'));

    final result = await api.fetchAlbumHymns(100);
    expect(result, isEmpty);
  });

  test('fetchMusic retorna hino parseado', () async {
    final api = createApi(
      _MockAdapter((req) {
        return '{"id_music":42,"name":"Detalhe","url_music":"/musics/foo.mp3"}';
      }),
    );

    final result = await api.fetchMusic(42);
    expect(result.id, 42);
    expect(result.title, 'Detalhe');
    expect(result.urlMusic, '/musics/foo.mp3');
  });

  test('fetchHymnal retorna lista', () async {
    final api = createApi(
      _MockAdapter((req) {
        return '[{"id_music":1,"name":"H1"},{"id_music":2,"name":"H2"}]';
      }),
    );

    final result = await api.fetchHymnal();
    expect(result.length, 2);
  });

  test('fetchMusicIndex retorna lista', () async {
    final api = createApi(
      _MockAdapter((req) {
        return '[{"id_music":1,"name":"H1"}]';
      }),
    );

    final result = await api.fetchMusicIndex();
    expect(result.length, 1);
  });

  test('languagePrefix muda endpoint', () async {
    String? requestedUrl;
    final api = createApi(
      _MockAdapter((req) {
        requestedUrl = req.path;
        return '[]';
      }),
    );
    api.languagePrefix = 'en';

    await api.fetchCategories();
    expect(requestedUrl, contains('en_categories'));
  });

  test('cacheBuster usa data atual na URL', () async {
    String? requestedUrl;
    final api = createApi(
      _MockAdapter((req) {
        requestedUrl = req.path;
        return '[]';
      }),
    );

    await api.fetchCategories();
    expect(requestedUrl, contains('20260810'));
  });

  test('erro 401 lanca LouvorjaApiException authFailed', () async {
    final api = createApi(_MockAdapter((req) => 401));

    expect(
      () => api.fetchCategories(),
      throwsA(
        predicate(
          (e) => e is LouvorjaApiException && e.code == 'errors.authFailed',
        ),
      ),
    );
  });

  test('erro 403 lanca LouvorjaApiException authFailed', () async {
    final api = createApi(_MockAdapter((req) => 403));

    expect(
      () => api.fetchCategories(),
      throwsA(
        predicate(
          (e) => e is LouvorjaApiException && e.code == 'errors.authFailed',
        ),
      ),
    );
  });

  test('erro 404 lanca LouvorjaApiException notFound', () async {
    final api = createApi(_MockAdapter((req) => 404));

    expect(
      () => api.fetchCategories(),
      throwsA(
        predicate(
          (e) => e is LouvorjaApiException && e.code == 'errors.notFound',
        ),
      ),
    );
  });
}
