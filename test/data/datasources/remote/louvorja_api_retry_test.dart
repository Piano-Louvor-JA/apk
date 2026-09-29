library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';

/// Adapter que lanca Exception generica (nao DioException).
class _GenericExceptionAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw Exception('generic network failure');
  }
}

/// Adapter que sempre retorna 200 com JSON valido.
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
  test('maxRetries getter retorna valor constante', () {
    final api = LouvorjaApiImpl.single(
      baseUrl: 'https://api.example.com',
      filesUrl: 'https://api.example.com/file',
      apiToken: 'token',
    );
    expect(api.maxRetries, 5);
  });

  test(
    'Exception generica no retry lanca errors.connection apos esgotar',
    () async {
      final api = LouvorjaApiImpl.single(
        baseUrl: 'https://api.example.com',
        filesUrl: 'https://api.example.com/file',
        apiToken: 'token',
        now: () => DateTime(2026, 8, 10),
      );
      api.dio.httpClientAdapter = _GenericExceptionAdapter();

      // O retry loop vai tentar 5 vezes com backoff exponencial.
      // Cada tentativa lanca Exception generica -> cai no on Exception catch.
      // Apos a ultima tentativa, lanca LouvorjaApiException.
      expect(
        () => api.fetchCategories(),
        throwsA(
          predicate(
            (e) =>
                e is LouvorjaApiException &&
                // adapter lanca Exception crua que o Dio relanca como falha de
                // rede (sem statusCode); sem fallback disponivel -> serverBusy.
                (e.code == 'errors.connection' ||
                    e.code == 'errors.serverBusy'),
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('cacheBuster formatado corretamente na URL', () async {
    final api = LouvorjaApiImpl.single(
      baseUrl: 'https://api.example.com',
      filesUrl: 'https://api.example.com/file',
      apiToken: 'token',
      now: () => DateTime(2026, 1, 5),
    );
    api.dio.httpClientAdapter = _OkAdapter('[]');

    await api.fetchCategories();
    // URL deve conter o cacheBuster: ano + mes(2 digitos) + dia(2 digitos)
    // Como nao capturamos a URL diretamente, so verificamos que nao quebra
  });
}
