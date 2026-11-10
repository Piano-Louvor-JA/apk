import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

void main() {
  test('lê configuração e reprodução do áudio do sorteio do desktop', () {
    final state =
        RemoteProtocol.parse(
              jsonEncode({
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
                'random': {
                  'mode': 'names',
                  'audioSource': 'custom',
                  'audioVolume': 35,
                  'audioMuted': true,
                  'audioPlaying': true,
                  'customAudioFile': 'Som.mp3',
                  'customAudioFiles': ['Som.mp3'],
                },
              }),
            )
            as RemotePlayerState;
    final audio = state.randomModule!;
    expect(audio.audioSupported, isTrue);
    expect(audio.audioVolume, 35);
    expect(audio.audioMuted, isTrue);
    expect(audio.audioPlaying, isTrue);
    expect(audio.customAudioFile, 'Som.mp3');
    expect(audio.customAudioFiles, ['Som.mp3']);
    final command =
        jsonDecode(
              RemoteCommand(
                id: 'som',
                action: RemoteAction.randomSetAudioVolume,
                volume: 75,
              ).encode(),
            )
            as Map;
    expect(command['action'], 'random.setAudioVolume');
    expect(command['value'], 75);
  });
}
