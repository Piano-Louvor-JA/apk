import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/core/services/playback_resolver.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

class LiturgyMusicPlayback {
  const LiturgyMusicPlayback({
    required this.detail,
    required this.source,
    required this.isLocal,
  });
  final Hymn detail;
  final String source;
  final bool isLocal;
}

abstract final class LiturgyPlayback {
  static Future<LiturgyMusicPlayback> resolve(
    LiturgyItem item, {
    required LiturgyCatalogRepository catalog,
    required OfflineMusicPort offline,
  }) async {
    final id = item.musicId;
    if (id == null) throw StateError('liturgy.parity.musicMissing');
    final local = await PlaybackResolver.localFor(
      musicId: id,
      instrumental: item.musicMode == 'instrumental',
      offline: offline,
    );
    if (local != null) {
      var detail = catalog.cachedMusic(id);
      if (detail == null) {
        try {
          detail = await catalog.music(id).timeout(const Duration(seconds: 3));
        } catch (_) {
          /* O áudio baixado continua disponível mesmo sem o catálogo. */
        }
      }
      detail ??= Hymn(id: id, title: item.name, durationMs: item.durationMs);
      return LiturgyMusicPlayback(detail: detail, source: local, isLocal: true);
    }
    final detail = await catalog.music(id);
    final path =
        (item.musicMode == 'instrumental'
            ? detail.urlInstrumental
            : detail.urlMusic) ??
        '';
    if (path.isEmpty) throw StateError('liturgy.parity.audioUnavailable');
    return LiturgyMusicPlayback(
      detail: detail,
      source: DownloadUrlBuilder.build(path),
      isLocal: false,
    );
  }
}
