/// EditsApi — portação APK read-only (SPEC piano-community-edits §7, padrão F0).
/// O APK CONSOME: edits `applied` (RF-08) e lista Minhas Edições do autor
/// (RF-05). Escrita (editar/publicar) permanece desktop/web — APK não edita.
library;

import 'package:dio/dio.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/core/platform_header.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';

import 'package:louvorja_piano_mobile/data/models/applied_edit_model.dart';

class EditsApiImpl {
  final Dio dio;
  final String apiBaseUrl;
  final Future<String?> Function() bearerToken;

  const EditsApiImpl({
    required this.dio,
    required this.apiBaseUrl,
    required this.bearerToken,
  });

  factory EditsApiImpl.production() {
    final database = ApiConfig.urlDatabase;
    return EditsApiImpl(
      dio: Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
        ),
      ),
      apiBaseUrl: database.endsWith('/json_db')
          ? database.substring(0, database.length - '/json_db'.length)
          : database,
      bearerToken: () async => (await CustomSessionStore().read())?.token,
    );
  }

  String _api(String path) => '$apiBaseUrl/v1/custom$path';

  Future<dynamic> _fetch(String path) async {
    final token = await bearerToken();
    return dio.request<dynamic>(
      _api(path),
      options: Options(
        method: 'GET',
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          ...clientPlatformHeaders(),
        },
      ),
    );
  }

  /// Edit `applied` (aprovado pelo concilio) para a música, ou null.
  /// Erro de rede → null: a oficial intacta é sempre o fallback seguro (RF-08).
  Future<AppliedEditModel?> fetchApplied(int musicId) async {
    try {
      final response = await _fetch('/edits/applied?musicIds=$musicId');
      final data = response.data;
      if (data is! Map) return null;
      final applied = data['applied'];
      if (applied is! List) return null;
      for (final item in applied) {
        if (item is Map && item['musicId'] == musicId) {
          return AppliedEditModel.fromJson(Map<String, dynamic>.from(item));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lista do autor: erros são propagados para diferenciar falha de lista vazia.
  Future<List<MyEditSummary>> fetchMine() async {
    final response = await _fetch('/edits/mine');
    final data = response.data;
    if (data is! List)
      throw const FormatException('Resposta de edições inválida');
    return data
        .whereType<Map>()
        .map((item) => MyEditSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
