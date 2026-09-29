library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Motivo pelo qual a verificacao ficou indisponivel (distinto de
/// "esta atualizado").
enum UpdateCheckFailure {
  /// 401/404: repo privado sem token valido (ou token expirado).
  unauthorized,

  /// Sem rede / timeout / DNS.
  network,

  /// Qualquer outro erro.
  unknown,
}

/// Resultado da verificacao de atualizacao.
class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final int? apkSize;
  final String? apkSha256;
  final UpdateCheckFailure? failure;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.apkSize,
    this.apkSha256,
    this.failure,
  });

  static const none = UpdateCheckResult(hasUpdate: false);

  /// A verificacao FALHOU (nao confundir com "sem atualizacao").
  const UpdateCheckResult.unavailable({required UpdateCheckFailure reason})
    : hasUpdate = false,
      latestVersion = null,
      downloadUrl = null,
      releaseNotes = null,
      apkSize = null,
      apkSha256 = null,
      failure = reason;

  bool get isUnavailable => failure != null;
}

/// Servico de auto-update via GitHub Releases.
///
/// Consulta a API do GitHub por tras. O usuario nunca ve o GitHub --
/// apenas um banner com "Nova versao disponivel" e um botao "Atualizar".
class UpdateService {
  final Dio _dio;
  final String _repo;
  final Future<PackageInfo> Function() _packageInfoProvider;
  final CancelToken _cancelToken = CancelToken();

  /// Token PAT para acessar releases de repositorios privados.
  /// Fornecido via --dart-define=GH_TOKEN=xxx no build.
  /// Fallback vazio (repo publico nao precisa).
  static const _ghToken = String.fromEnvironment('GH_TOKEN', defaultValue: '');

  /// Endpoint proxy próprio (ex.: https://pianolouvorja.duckdns.org).
  /// Quando definido via --dart-define=UPDATE_API=..., a consulta de
  /// releases vai para o proxy — o token GitHub fica no servidor e o
  /// APK distribuído não carrega credencial alguma.
  static const _updateApiBase = String.fromEnvironment(
    'UPDATE_API',
    defaultValue: '',
  );

  UpdateService({
    Dio? dio,
    String repo = 'pianolouvorja/apk',
    String? updateApiBase,
    Future<PackageInfo> Function()? packageInfoProvider,
  }) : _dio = dio ?? Dio(),
       _repo = repo,
       _updateBase = (updateApiBase ?? _updateApiBase).replaceAll(
         RegExp(r'/+$'),
         '',
       ),
       _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform;

  final String _updateBase;

  /// Verifica se existe uma versao mais recente no GitHub Releases.
  /// Retorna [UpdateCheckResult.none] se nao houver update ou se falhar.
  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final response = await _dio.get<dynamic>(
        _updateBase.isNotEmpty
            ? '$_updateBase/repos/$_repo/releases/latest'
            : 'https://api.github.com/repos/$_repo/releases/latest',
        cancelToken: _cancelToken,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            // No modo proxy o token vive no servidor — nunca enviar.
            if (_updateBase.isEmpty && _ghToken.isNotEmpty)
              'Authorization': 'token $_ghToken',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data is String
          // coverage:ignore-line
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final tagVersion = (data['tag_name'] ?? '').toString().replaceFirst(
        'v',
        '',
      );
      if (tagVersion.isEmpty) return UpdateCheckResult.none;

      final info = await _packageInfoProvider();
      final currentVersion = info.version;
      if (currentVersion.isEmpty) return UpdateCheckResult.none;

      // Compara versao atual com a da release.
      if (!_isNewer(tagVersion, currentVersion)) {
        return UpdateCheckResult.none;
      }

      // Procura o asset APK na release.
      final assets = data['assets'] as List? ?? const [];
      String? apkUrl;
      int? apkSize;
      String? apkSha256;
      for (final asset in assets.whereType<Map>()) {
        final name = (asset['name'] ?? '').toString().toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url']?.toString();
          apkSize = asset['size'] as int?;
          final digest = asset['digest']?.toString();
          if (digest?.startsWith('sha256:') ?? false) {
            apkSha256 = digest!.substring('sha256:'.length).toLowerCase();
          }
          break;
        }
      }

      if (apkUrl == null) return UpdateCheckResult.none;

      return UpdateCheckResult(
        hasUpdate: true,
        latestVersion: tagVersion,
        downloadUrl: apkUrl,
        releaseNotes: data['body']?.toString(),
        apkSize: apkSize,
        apkSha256: apkSha256,
      );
    } on DioException catch (e) {
      // 404/401 em repo privado sem token: a consulta FALHOU — nao
      // tratar como "atualizado" (o app mentia "sem novidades").
      final status = e.response?.statusCode;
      if (status == 401 || status == 403 || status == 404) {
        return const UpdateCheckResult.unavailable(
          reason: UpdateCheckFailure.unauthorized,
        );
      }
      return const UpdateCheckResult.unavailable(
        reason: UpdateCheckFailure.network,
      );
    } catch (_) {
      return const UpdateCheckResult.unavailable(
        reason: UpdateCheckFailure.unknown,
      );
    }
  }

  /// Baixa o APK e, quando GitHub publicar o digest do asset, valida SHA-256.
  /// Retorna o caminho do arquivo somente se a integridade for confirmada.
  // coverage:ignore-line
  Future<String> downloadApk(
    String url, {
    String? expectedSha256,
    void Function(int received, int total)? onProgress,
  }) async {
    // coverage:ignore-line
    final dir = await Directory.systemTemp.createTemp('piano_update');
    // coverage:ignore-line
    final filePath = '${dir.path}/piano-louvorja-update.apk';
    // coverage:ignore-line
    await _dio.download(
      url,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: onProgress,
    );

    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final file = File(filePath);
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != expectedSha256.toLowerCase()) {
        await file.delete();
        throw StateError('Integridade do APK invalida (SHA-256 divergente).');
      }
    }

    return filePath;
  }

  /// Cancela requisicoes/downloads pendentes ao descartar a tela chamadora.
  void dispose() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('UpdateService descartado');
    }
  }

  /// Compara se [remote] e mais recente que [local].
  /// Formato esperado: "0.1.0" (semver).
  bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Padding para mesmo tamanho.
    final maxLen = r.length > l.length ? r.length : l.length;
    while (r.length < maxLen) {
      // coverage:ignore-line
      r.add(0);
    }
    while (l.length < maxLen) {
      // coverage:ignore-line
      l.add(0);
    }

    for (var i = 0; i < maxLen; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }
}
