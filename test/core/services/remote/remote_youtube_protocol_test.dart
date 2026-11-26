import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

Map<String, dynamic> stateJson([Map<String, dynamic> extra = const {}]) => {
  'v': 1,
  'type': 'state',
  'player': {
    'playing': false,
    'positionMs': 0,
    'durationMs': 0,
    'slideIndex': 0,
    'slideCount': 0,
    'volume': 80,
    'canPrevious': false,
    'canNext': false,
  },
  ...extra,
};

void main() {
  test('youtube.play leva link, título e canal do vídeo', () {
    final command = RemoteCommand(
      id: 'yt1',
      action: RemoteAction.youtubePlay,
      url: 'https://www.youtube.com/watch?v=AAAAAAAAAAA',
      name: 'Castelo Forte',
      channel: 'Arautos do Rei',
    );
    final encoded = jsonDecode(command.encode()) as Map;
    expect(encoded['action'], 'youtube.play');
    expect(encoded['url'], 'https://www.youtube.com/watch?v=AAAAAAAAAAA');
    expect(encoded['name'], 'Castelo Forte');
    expect(encoded['channel'], 'Arautos do Rei');
    expect(RemoteAction.fromWire('youtube.play'), RemoteAction.youtubePlay);
  });

  test('youtube.favorite leva link, marcação, título e canal', () {
    final encoded =
        jsonDecode(
              RemoteCommand(
                id: 'yt3',
                action: RemoteAction.youtubeFavorite,
                url: 'https://www.youtube.com/watch?v=AAAAAAAAAAA',
                enabled: false,
                name: 'Vai Começar',
                channel: 'Quarteto Athus',
              ).encode(),
            )
            as Map;
    expect(encoded['action'], 'youtube.favorite');
    expect(encoded['enabled'], false);
    expect(encoded['channel'], 'Quarteto Athus');
    expect(
      RemoteAction.fromWire('youtube.favorite'),
      RemoteAction.youtubeFavorite,
    );
  });

  test('sem canal, o campo não vai', () {
    final encoded =
        jsonDecode(
              RemoteCommand(
                id: 'yt2',
                action: RemoteAction.youtubePlay,
                url: 'u',
              ).encode(),
            )
            as Map;
    expect(encoded.containsKey('channel'), isFalse);
  });

  test(
    'o estado diz se o desktop toca YouTube pelo remoto (e sobrevive ao roundtrip)',
    () {
      final yes =
          RemoteProtocol.parse(
                jsonEncode(
                  stateJson({
                    'youtube': {'canPlay': true},
                  }),
                ),
              )
              as RemotePlayerState;
      expect(yes.youtubeCanPlay, isTrue);
      final restored = RemoteProtocol.parse(yes.encode()) as RemotePlayerState;
      expect(restored.youtubeCanPlay, isTrue);

      // desktop antigo (sem o campo) ou valor estranho: não mostra o YouTube
      expect(
        (RemoteProtocol.parse(jsonEncode(stateJson())) as RemotePlayerState)
            .youtubeCanPlay,
        isFalse,
      );
      expect(
        (RemoteProtocol.parse(jsonEncode(stateJson({'youtube': 'sim'})))
                as RemotePlayerState)
            .youtubeCanPlay,
        isFalse,
      );
    },
  );
}
