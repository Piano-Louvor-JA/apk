library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';

class _OkAdapter implements HttpClientAdapter {
  final String json;
  _OkAdapter(this.json);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
  LouvorjaApiImpl createApi(String json) {
    final api = LouvorjaApiImpl.single(
      baseUrl: 'https://api.example.com/json_db',
      filesUrl: 'https://api.example.com/file',
      apiToken: 'token',
      languagePrefix: 'pt',
      now: () => DateTime(2026, 8, 10),
    );
    api.dio.httpClientAdapter = _OkAdapter(json);
    return api;
  }

  test('fetchBibleBooks retorna livros parseados', () async {
    final api = createApi(
      '[{"id_bible_book":1,"name":"Genesis","abbreviation":"Gn","chapters":50,"book_number":1,"id_language":"pt"}]',
    );
    final result = await api.fetchBibleBooks();
    expect(result.length, 1);
    expect(result[0].name, 'Genesis');
    expect(result[0].abbreviation, 'Gn');
    expect(result[0].chapters, 50);
    expect(result[0].bookNumber, 1);
  });

  test('fetchBibleVersions retorna versoes parseadas', () async {
    final api = createApi(
      '[{"id_bible_version":1,"abbreviation":"ARA","name":"Almeida","id_language":"pt"}]',
    );
    final result = await api.fetchBibleVersions();
    expect(result.length, 1);
    expect(result[0].abbreviation, 'ARA');
    expect(result[0].name, 'Almeida');
  });

  test('fetchBibleChapter retorna versiculos', () async {
    final api = createApi('{"1":"No principio","2":"E a terra"}');
    final result = await api.fetchBibleChapter(1, 1, 1);
    expect(result['1'], 'No principio');
    expect(result['2'], 'E a terra');
  });
}
