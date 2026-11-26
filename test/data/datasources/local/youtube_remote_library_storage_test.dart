import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_youtube_library.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/youtube_remote_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

const a = 'AAAAAAAAAAA', b = 'BBBBBBBBBBB', c = 'CCCCCCCCCCC';

Map<String, dynamic> entry(String id) => {
  'videoId': id,
  'title': 'Hino $id',
  'channel': 'Quarteto Athus',
  'thumbnail': '',
  'durationText': '',
  'playedAt': 1,
  'playCount': 2,
};

RemotePlayerState stateWith({
  List<Object?>? history,
  List<Object?>? favorites,
  String key = 'k1',
}) => RemotePlayerState(
  playing: false,
  position: Duration.zero,
  duration: Duration.zero,
  slideIndex: 0,
  slideCount: 0,
  volume: 80,
  canPrevious: false,
  canNext: false,
  youtubeCanPlay: true,
  youtubeLibraryKey: key,
  youtubeHistory: history,
  youtubeFavorites: favorites,
);

void main() {
  late List<RemoteCommand> sent;
  late YoutubeRemoteLibraryStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RemoteYoutubeLibrary.reset();
    sent = [];
    storage = YoutubeRemoteLibraryStorage(send: (command) async => sent.add(command));
    RemoteYoutubeLibrary.remember(
      stateWith(history: [entry(a), entry(b), entry(c)], favorites: [entry(b)]),
    );
  });

  test('histórico e favoritos são os do desktop', () async {
    expect((await storage.history()).map((e) => e.videoId), [a, b, c]);
    expect((await storage.history()).first.playCount, 2);
    expect((await storage.favorites()).map((e) => e.videoId), [b]);
  });

  test('estado sem as listas (só a chave) mantém o que já chegou', () async {
    final before = RemoteYoutubeLibrary.changes.value;
    RemoteYoutubeLibrary.remember(stateWith());
    expect((await storage.history()).map((e) => e.videoId), [a, b, c]);
    expect(RemoteYoutubeLibrary.changes.value, before);
  });

  test('remover, reordenar e limpar mandam o comando e já mostram o resultado', () async {
    expect((await storage.removeFromHistory(b)).map((e) => e.videoId), [a, c]);
    expect(sent.last.action, RemoteAction.youtubeHistoryRemove);
    expect(sent.last.url, b);

    expect((await storage.reorderHistory(c, a)).map((e) => e.videoId), [c, a]);
    expect(sent.last.action, RemoteAction.youtubeHistoryReorder);
    expect(sent.last.url, c);
    expect(sent.last.targetId, a);

    expect(await storage.clearHistory(), isEmpty);
    expect(sent.last.action, RemoteAction.youtubeHistoryClear);
    expect(await storage.history(), isEmpty);
  });

  test('favoritar e desfavoritar gravam no desktop', () async {
    const video = YoutubeVideo(videoId: a, title: 'Deus o Pode', channel: 'Quarteto Athus');
    expect((await storage.toggleFavorite(video)).map((e) => e.videoId), [a, b]);
    expect(sent.last.action, RemoteAction.youtubeFavorite);
    expect(sent.last.enabled, isTrue);
    expect(sent.last.url, video.watchUrl);
    expect(sent.last.name, 'Deus o Pode');

    expect((await storage.toggleFavorite(video)).map((e) => e.videoId), [b]);
    expect(sent.last.enabled, isFalse);

    expect((await storage.reorderFavorites(b, b)).map((e) => e.videoId), [b]);
    expect(sent.last.action, RemoteAction.youtubeFavoritesReorder);
  });

  test('tocar não grava no celular: quem registra é o desktop', () async {
    const video = YoutubeVideo(videoId: 'DDDDDDDDDDD', title: 'Novo');
    expect((await storage.recordPlay(video)).map((e) => e.videoId), [a, b, c]);
    expect(sent, isEmpty);
  });

  test('o estado do desktop traz e devolve as listas (roundtrip)', () {
    final state = stateWith(history: [entry(a)], favorites: const []);
    final parsed = RemoteProtocol.parse(state.encode()) as RemotePlayerState;
    expect(parsed.youtubeLibraryKey, 'k1');
    expect(parsed.youtubeHistory, hasLength(1));
    expect(parsed.youtubeFavorites, isEmpty);
    final keyOnly = RemoteProtocol.parse(stateWith().encode()) as RemotePlayerState;
    expect(keyOnly.youtubeHistory, isNull);
  });
}
