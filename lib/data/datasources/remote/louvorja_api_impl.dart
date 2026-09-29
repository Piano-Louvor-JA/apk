library;

import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/core/utils/scripture_format.dart';

/// Exceção user-friendly para erros de rede.
///
/// [code] mapeia para uma chave de tradução i18n.
/// [detail] mantém o erro técnico original para log.

/// Implementação de [LouvorjaApiClient] usando Dio com retry e cache-buster.
class LouvorjaApiImpl implements LouvorjaApiClient {
  final Dio _dio;
  final List<String> _baseUrls;
  final List<String> _filesUrls;
  final String apiToken;
  final DateTime Function() _now;

  /// Base em uso (a primaria, ou o fallback apos o primeiro failover).
  String get baseUrl => _baseUrls.first;
  String get filesUrl => _filesUrls.first;

  int _activeIndex = 0;

  /// indice do host em uso na cascata (0 = primario). Visivel pra testes
  /// e pra telemetria simples.
  @visibleForTesting
  int get activeUrlIndex => _activeIndex;

  @override
  String languagePrefix;

  static const _maxRetries = 5;

  @visibleForTesting
  int get maxRetries => _maxRetries;

  /// Construtor com fallback: recebe listas de URLs (primaria primeiro).
  /// Se so uma URL for passada, comporta-se como antes (sem fallback).
  LouvorjaApiImpl({
    required List<String> baseUrls,
    required List<String> filesUrls,
    required this.apiToken,
    this.languagePrefix = 'pt',
    DateTime Function()? now,
  }) : _baseUrls = baseUrls,
       _filesUrls = filesUrls,
       _now = now ?? DateTime.now,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 30),
           headers: {'Api-Token': apiToken},
         ),
       );

  /// Construtor de compatibilidade (uma URL, sem fallback) — usado por
  /// chamadas existentes e testes antigos.
  factory LouvorjaApiImpl.single({
    required String baseUrl,
    required String filesUrl,
    required String apiToken,
    String languagePrefix = 'pt',
    DateTime Function()? now,
  }) => LouvorjaApiImpl(
    baseUrls: [baseUrl],
    filesUrls: [filesUrl],
    apiToken: apiToken,
    languagePrefix: languagePrefix,
    now: now,
  );

  @visibleForTesting
  Dio get dio => _dio;

  String get _cacheBuster {
    final d = _now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  @override
  String resolveMediaUrl(String relativePath) {
    return '${_filesUrls[_activeIndex]}/$relativePath';
  }

  Future<dynamic> _fetchJson(String filename) async {
    final cacheBuster = _cacheBuster;

    // Failover: cascade de hosts. Cada host recebe as tentativas de retry
    // completas; falha de REDE (sem resposta HTTP) pula pro proximo host
    // imediatamente (host morto nao merece 5 retries).
    for (var hostIdx = _activeIndex; hostIdx < _baseUrls.length; hostIdx++) {
      _activeIndex = hostIdx;
      final url = '${_baseUrls[hostIdx]}/$filename?$cacheBuster';

      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final response = await _dio.get<dynamic>(url);
          return response.data is String
              ? jsonDecode(response.data as String) // coverage:ignore-line
              : response.data;
        } on DioException catch (e) {
          final statusCode = e.response?.statusCode;
          final isNetworkFailure = statusCode == null;
          final shouldRetry =
              statusCode == 429 || (statusCode != null && statusCode >= 500);

          // coverage:ignore-start
          // Falha de rede: proximo host imediatamente.
          if (isNetworkFailure) break;

          final isLastAttempt = attempt >= _maxRetries - 1;
          if (!shouldRetry) {
            if (statusCode == 401 || statusCode == 403) {
              throw const LouvorjaApiException(
                'errors.authFailed',
                'Token inválido ou ausente',
              );
            } else if (statusCode == 404) {
              throw const LouvorjaApiException(
                'errors.notFound',
                'Recurso não encontrado',
              );
            }
            throw LouvorjaApiException(
              'errors.connection',
              'Erro de conexão: $e',
            );
          }
          // 429/5xx: se esgotou retries neste host, tenta o proximo.
          if (isLastAttempt) break;

          // Respeita Retry-After se o servidor enviar
          final retryAfter = e.response?.headers.value('retry-after');
          if (retryAfter != null) {
            final raSec = int.tryParse(retryAfter) ?? 2;
            await Future.delayed(Duration(seconds: raSec));
          }
          // coverage:ignore-end
        } on Exception catch (e) {
          if (attempt >= _maxRetries - 1) {
            throw LouvorjaApiException(
              'errors.connection',
              'Falha de rede: $e',
            );
          }
        }

        final delayMs = (1500 * pow(1.5, attempt)).toInt();
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw const LouvorjaApiException('errors.serverBusy', 'Servidor ocupado');
  }

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    final data = await _fetchJson('${languagePrefix}_categories');
    final list = data as List<dynamic>;
    return list
        .map((e) => AlbumCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async {
    final data = await _fetchJson('album_$albumId');
    final map = data as Map<String, dynamic>;
    final musics = map['musics'] as List<dynamic>?;
    return musics
            ?.map((e) => Hymn.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
  }

  @override
  Future<Hymn> fetchMusic(int musicId) async {
    final data = await _fetchJson('music_$musicId');
    return Hymn.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Hymn>> fetchHymnal() async {
    final data = await _fetchJson('${languagePrefix}_hymnal');
    final list = data as List<dynamic>;
    return list.map((e) => Hymn.fromJson(e as Map<String, dynamic>)).toList();
  }

  // coverage:ignore-start
  @override
  Future<List<Hymn>> fetchHymnal1996() async {
    final data = await _fetchJson('${languagePrefix}_hymnal_1996');
    final list = data as List<dynamic>;
    return list.map((e) => Hymn.fromJson(e as Map<String, dynamic>)).toList();
  }
  // coverage:ignore-end

  @override
  Future<List<Hymn>> fetchMusicIndex() async {
    final data = await _fetchJson('${languagePrefix}_musics');
    final list = data as List<dynamic>;
    return list.map((e) => Hymn.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<BibleBook>> fetchBibleBooks() async {
    // Biblia disponivel em pt e es. EN nao tem. Fallback pt.
    final prefix = languagePrefix == 'es' ? 'es' : 'pt';
    final data = await _fetchJson('${prefix}_bible_book');
    final list = data as List<dynamic>;
    return list
        .map((e) => BibleBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<BibleVersion>> fetchBibleVersions() async {
    final prefix = languagePrefix == 'es' ? 'es' : 'pt';
    final data = await _fetchJson('${prefix}_bible_version');
    final list = data as List<dynamic>;
    return list.map((e) {
      final json = Map<String, dynamic>.from(e as Map<String, dynamic>);
      // A API ES omite id_language; fixa o prefixo consultado.
      json['id_language'] = prefix;
      return BibleVersion.fromJson(json);
    }).toList();
  }

  @override
  Future<Map<String, String>> fetchBibleChapter(
    int versionId,
    int bookId,
    int chapter,
  ) async {
    final key = ScriptureFormat.chapterRecordKey(versionId, bookId, chapter);
    final data = await _fetchJson(key);
    final map = data as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  }
}
