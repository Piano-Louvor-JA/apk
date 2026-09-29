import 'dart:io';

import 'package:dio/dio.dart';

import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

/// Resultado do upload de mídia custom.
class CustomFileUpload {
  final int idFile;
  final String url;
  final String name;
  final int size;

  const CustomFileUpload({
    required this.idFile,
    required this.url,
    required this.name,
    required this.size,
  });
}

/// Upload de arquivos de mídia custom (áudio/imagem) — POST /v1/custom/files.
///
/// Multipart não passa pelo CustomFetch (que é JSON) — usa Dio próprio.
class CustomFileApi {
  final Dio _dio;
  final String apiBaseUrl;

  CustomFileApi({Dio? dio, String? apiBaseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(minutes: 5),
            ),
          ),
      apiBaseUrl = apiBaseUrl ?? _baseFromConfig();

  static String _baseFromConfig() {
    final db = ApiConfig.urlDatabase;
    return db.endsWith('/json_db')
        ? db.substring(0, db.length - '/json_db'.length)
        : db;
  }

  /// Envia [file] como multipart. [kind] = 'audio' | 'imagens'.
  /// [onProgress] 0.0..1.0.
  Future<CustomFileUpload> upload(
    File file, {
    required String kind,
    required String bearerToken,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'kind': kind,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '$apiBaseUrl/v1/custom/files',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $bearerToken'}),
      onSendProgress: (sent, total) =>
          onProgress?.call(total > 0 ? sent / total : 0),
    );
    final data = res.data ?? const {};
    return CustomFileUpload(
      idFile: (data['id_file'] as num?)?.toInt() ?? 0,
      url: (data['url'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      size: (data['size'] as num?)?.toInt() ?? 0,
    );
  }
}
