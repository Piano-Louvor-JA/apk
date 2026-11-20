import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// Busca e playlists do YouTube (sem chave de API). Nunca lança: erro vem
/// no campo `error` do resultado.
abstract class YoutubeSearchRepository {
  Future<YoutubeSearchResult> search(String query);
  Future<YoutubeSearchResult> more(YoutubeContinuation continuation);
  Future<YoutubePlaylistResult> playlist(String text);
}
