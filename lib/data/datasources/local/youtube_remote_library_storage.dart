import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_youtube_library.dart';
import 'package:louvorja_piano_mobile/core/utils/reorder.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// Biblioteca do YouTube no controle remoto: histórico e favoritos são os do
/// DESKTOP (a origem). Ler usa o que o desktop mandou; mudar manda o comando
/// e já mostra o resultado, até o desktop devolver a lista dele.
/// Coletâneas, canais e buscas recentes continuam no celular.
class YoutubeRemoteLibraryStorage extends YoutubeLibraryStorage {
  YoutubeRemoteLibraryStorage({
    super.prefs,
    Future<void> Function(RemoteCommand command)? send,
  }) : _sendFn = send;

  final Future<void> Function(RemoteCommand command)? _sendFn;

  Future<void> _send(
    RemoteAction action, {
    String? url,
    String? targetId,
    bool? enabled,
    String? name,
    String? channel,
  }) => (_sendFn ?? RemoteSession.instance.send)(
    RemoteCommand(
      id: 'ytl${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      url: url,
      targetId: targetId,
      enabled: enabled,
      name: name,
      channel: channel,
    ),
  );

  static List<YoutubeSavedVideo> _parse(List<Object?> raw) {
    final seen = <String>{};
    return [
      for (final item in raw)
        if (YoutubeSavedVideo.fromJson(item) case final entry?)
          if (seen.add(entry.videoId)) entry,
    ];
  }

  List<YoutubeSavedVideo> _showHistory(List<YoutubeSavedVideo> list) {
    RemoteYoutubeLibrary.applyLocal(
      history: [for (final e in list) e.toJson()],
    );
    return list;
  }

  List<YoutubeSavedVideo> _showFavorites(List<YoutubeSavedVideo> list) {
    RemoteYoutubeLibrary.applyLocal(
      favorites: [for (final e in list) e.toJson(count: false)],
    );
    return list;
  }

  @override
  Future<List<YoutubeSavedVideo>> history() async =>
      _parse(RemoteYoutubeLibrary.history);

  @override
  Future<List<YoutubeSavedVideo>> favorites() async =>
      _parse(RemoteYoutubeLibrary.favorites);

  /// Quem registra é o desktop, ao receber o `youtube.play`.
  @override
  Future<List<YoutubeSavedVideo>> recordPlay(YoutubeVideo video) => history();

  @override
  Future<List<YoutubeSavedVideo>> removeFromHistory(String videoId) async {
    await _send(RemoteAction.youtubeHistoryRemove, url: videoId);
    return _showHistory(
      (await history()).where((e) => e.videoId != videoId).toList(),
    );
  }

  @override
  Future<List<YoutubeSavedVideo>> clearHistory() async {
    await _send(RemoteAction.youtubeHistoryClear);
    return _showHistory(const []);
  }

  @override
  Future<List<YoutubeSavedVideo>> reorderHistory(
    String fromId,
    String toId,
  ) async {
    await _send(RemoteAction.youtubeHistoryReorder, url: fromId, targetId: toId);
    return _showHistory(
      moveById(await history(), (e) => e.videoId, fromId, toId),
    );
  }

  @override
  Future<List<YoutubeSavedVideo>> reorderFavorites(
    String fromId,
    String toId,
  ) async {
    await _send(
      RemoteAction.youtubeFavoritesReorder,
      url: fromId,
      targetId: toId,
    );
    return _showFavorites(
      moveById(await favorites(), (e) => e.videoId, fromId, toId),
    );
  }

  @override
  Future<List<YoutubeSavedVideo>> toggleFavorite(YoutubeVideo video) async {
    final list = await favorites();
    if (!YoutubeVideo.isValidId(video.videoId)) return list;
    final favorite = !list.any((e) => e.videoId == video.videoId);
    await _send(
      RemoteAction.youtubeFavorite,
      url: video.watchUrl,
      enabled: favorite,
      name: video.title,
      channel: video.channel.isEmpty ? null : video.channel,
    );
    return _showFavorites(
      favorite
          ? [YoutubeSavedVideo.from(video), ...list]
          : list.where((e) => e.videoId != video.videoId).toList(),
    );
  }
}
