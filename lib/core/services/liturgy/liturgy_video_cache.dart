import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'package:louvorja_piano_mobile/domain/repositories/liturgy_link_repository.dart';

/// Arquivos só ficam disponíveis após download completo e rename atômico.
class LiturgyVideoCache {
  const LiturgyVideoCache(this.directory, this.remote);
  final Directory directory;
  final LiturgyLinkRepository remote;
  String _path(String raw) {
    final url = LiturgyWebTarget.parse(raw)?.url ?? raw;
    return '${directory.path}/${sha256.convert(utf8.encode(url))}.mp4';
  }

  Future<String?> find(String url) async {
    final file = File(_path(url));
    return await file.exists() && await file.length() > 0 ? file.path : null;
  }

  Future<String> download(
    String url, {
    void Function(int, int)? onProgress,
  }) async {
    final existing = await find(url);
    if (existing != null) return existing;
    await directory.create(recursive: true);
    final path = _path(url);
    final partial = File('$path.part');
    try {
      await remote.download(url, partial.path, onProgress: onProgress);
      if (!await partial.exists() || await partial.length() == 0)
        throw StateError('empty-video');
      await partial.rename(path);
      return path;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }
}
