import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

void main() {
  test('estado da playlist preserva listas, fila e posição no roundtrip', () {
    final raw = {
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
        'canNext': true,
      },
      'playlist': {
        'lists': [
          {
            'id': 'p1',
            'name': 'Culto',
            'items': [
              {'musicId': 1, 'albumId': 3, 'title': 'Hino'},
            ],
          },
        ],
        'queue': [
          {'musicId': 1, 'title': 'Hino'},
        ],
        'queueIndex': 0,
        'queueLabel': 'Culto',
        'shuffled': true,
      },
    };
    final state = RemoteProtocol.parse(jsonEncode(raw)) as RemotePlayerState;
    expect(state.playlistModule!.lists.single.items.single.title, 'Hino');
    final restored = RemoteProtocol.parse(state.encode()) as RemotePlayerState;
    expect(restored.playlistModule!.queueIndex, 0);
    expect(restored.playlistModule!.shuffled, isTrue);
    expect(restored.playlistModule!.queueLabel, 'Culto');
  });
  test('faixa avulsa envia id da lista e índice', () {
    final command = RemoteCommand(
      id: 'p',
      action: RemoteAction.playlistTrack,
      targetId: 'p1',
      index: 2,
      mode: 'instrumental',
    );
    final encoded = jsonDecode(command.encode()) as Map;
    expect(encoded['action'], 'playlist.track');
    expect(encoded['targetId'], 'p1');
    expect(encoded['value'], 2);
  });
}
