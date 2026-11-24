import 'package:louvorja_piano_mobile/domain/entities/youtube_channel.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// Busca e playlists do YouTube (sem chave de API). Nunca lança: erro vem
/// no campo `error` do resultado.
abstract class YoutubeSearchRepository {
  Future<YoutubeSearchResult> search(String query);
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation);
  Future<YoutubePlaylistResult> playlist(String text);

  /// Canal (link, @handle ou id `UC…`) e as playlists da aba "Playlists".
  Future<YoutubeChannelResult> channel(String text);

  /// Canais sobre o tema, puxando para os adventistas.
  Future<YoutubeChannelSearchResult> searchChannels(String query);
}
