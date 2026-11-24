import 'dart:async';

import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

export 'youtube_default_channels.dart';

/// Vídeos de uma playlist (ou do canal unido). `error`: `empty`, `network`,
/// `http-<status>`…
typedef ChannelVideosResult = ({List<YoutubeVideo> items, String? error});

/// Lê as playlists dos canais com cache em memória: abrir de novo não vai à
/// rede, pedidos simultâneos viram um só e erro não fica guardado.
class ChannelPlaylistLoader {
  ChannelPlaylistLoader(this._fetch);

  final Future<YoutubePlaylistResult> Function(String id) _fetch;
  final _cache = <String, List<YoutubeVideo>>{};
  final _pending = <String, Future<ChannelVideosResult>>{};

  List<YoutubeVideo>? cached(String id) => _cache[id];

  Future<ChannelVideosResult> load(String id, {bool force = false}) {
    final hit = _cache[id];
    if (hit != null && !force) return Future.value((items: hit, error: null));
    final running = _pending[id];
    if (running != null) return running;
    // Bloco sem retorno: `remove` devolve a própria Future e o whenComplete
    // ficaria esperando por ela.
    final request = _fetchOnce(id).whenComplete(() {
      _pending.remove(id);
    });
    _pending[id] = request;
    return request;
  }

  Future<ChannelVideosResult> _fetchOnce(String id) async {
    try {
      final result = await _fetch(id);
      if (result.items.isNotEmpty) {
        _cache[id] = result.items;
        return (items: result.items, error: null);
      }
      return (items: const <YoutubeVideo>[], error: result.error ?? 'empty');
    } catch (_) {
      return (items: const <YoutubeVideo>[], error: 'network');
    }
  }
}

/// Canal unido: os vídeos de todas as playlists, na ordem delas, sem repetir.
/// Se alguma falhar, devolve o erro (e nenhum vídeo) para não mostrar o
/// hinário pela metade; as que deram certo ficam no cache.
Future<ChannelVideosResult> loadChannelVideos(
  YoutubeChannel channel,
  ChannelPlaylistLoader loader,
) async {
  final results = await Future.wait(
    channel.playlists.map((p) => loader.load(p.id)),
  );
  final failed = results
      .where((r) => r.error != null && r.error != 'empty')
      .firstOrNull;
  if (failed != null) return (items: const <YoutubeVideo>[], error: failed.error);
  final seen = <String>{};
  final items = [
    for (final result in results)
      for (final video in result.items)
        if (seen.add(video.videoId)) video,
  ];
  return items.isEmpty
      ? (items: const <YoutubeVideo>[], error: 'empty')
      : (items: items, error: null);
}

/// Filtro da lista do canal. Só um número ("15") acha o hino com esse número
/// ("Hino 15", não o 115 nem o 150); texto filtra pelo título, sem acento.
List<YoutubeVideo> filterChannelVideos(List<YoutubeVideo> list, String query) {
  final q = query.trim();
  if (RegExp(r'^\d+$').hasMatch(q)) {
    final number = RegExp(
      '\\bhino\\s*0*${int.parse(q)}\\b',
      caseSensitive: false,
    );
    return list.where((v) => number.hasMatch(v.title)).toList();
  }
  return filterYoutubeVideos(list, q, (v) => '${v.title} ${v.channel}');
}
