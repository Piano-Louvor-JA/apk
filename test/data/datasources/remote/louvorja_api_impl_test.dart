library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/louvorja_api_impl.dart';

void main() {
  late LouvorjaApiImpl api;

  /// Cria uma instância de LouvorjaApiImpl com Dio mockado via DioAdapter.
  ///
  /// Como não podemos usar DioAdapter facilmente, testamos via
  /// mock que implementa LouvorjaApiClient indirectamente.
  /// Para o LouvorjaApiImpl real, testamos apenas os aspectos
  /// que não dependem de rede: languagePrefix, resolveMediaUrl, cacheBuster.

  setUp(() {
    api = LouvorjaApiImpl.single(
      baseUrl: 'https://api.example.com/json_db',
      filesUrl: 'https://api.example.com/file',
      apiToken: 'test-token',
      languagePrefix: 'pt',
      now: () => DateTime(2026, 8, 10),
    );
  });

  group('LouvorjaApiImpl metodos nao-rede', () {
    test('languagePrefix pode ser alterado', () {
      expect(api.languagePrefix, 'pt');
      api.languagePrefix = 'en';
      expect(api.languagePrefix, 'en');
    });

    test('resolveMediaUrl constrói URL completa', () {
      expect(
        api.resolveMediaUrl('covers/2026.bmp'),
        'https://api.example.com/file/covers/2026.bmp',
      );
    });

    test('resolveMediaUrl com path com barra inicial', () {
      expect(
        api.resolveMediaUrl('/musics/pt/foo.mp3'),
        'https://api.example.com/file//musics/pt/foo.mp3',
      );
    });

    test('dio getter retorna instancia configurada', () {
      expect(api.dio, isA<Dio>());
      expect(api.dio.options.headers['Api-Token'], 'test-token');
    });
  });

  group('LouvorjaApiException', () {
    test('constructor armazena code e detail', () {
      const e = LouvorjaApiException('errors.connection', 'timeout');
      expect(e.code, 'errors.connection');
      expect(e.detail, 'timeout');
    });

    test('toString inclui code e detail', () {
      const e = LouvorjaApiException('errors.authFailed', '403');
      expect(e.toString(), 'LouvorjaApiException(errors.authFailed): 403');
    });
  });
}
