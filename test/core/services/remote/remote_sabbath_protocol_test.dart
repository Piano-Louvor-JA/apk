import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
void main() {
  test('contagem, áudio e marcos da Escola Sabatina preservados no protocolo', () {
    const original = RemotePlayerState(playing: false, position: Duration.zero, duration: Duration.zero, slideIndex: 0, slideCount: 0, volume: 80, canPrevious: false, canNext: false,
      sabbathModule: RemoteSabbathState(status: 'running', remainingMs: 123000, audioVolume: 65, audioMuted: true, audioLang: 'fr', openingPlayback: 'playing', markers: [RemoteSabbathMarker(id: '5min', offsetMs: 300000, preset: '5min_es')], presets: [RemoteSabbathPreset(id: 'beep')], scheduleMode: 'endOnly', endTime: '10:45'));
    final state = RemoteProtocol.parse(original.encode()) as RemotePlayerState;
    final school = state.sabbathModule!;
    expect(school.remainingMs, 123000);
    expect(school.audioVolume, 65);
    expect(school.audioMuted, isTrue);
    expect(school.openingPlayback, 'playing');
    expect(school.endTime, '10:45');
    expect(school.markers.single.preset, '5min_es');
    expect(school.presets.single.id, 'beep');
  });
  test('mensagem de peer antigo segue válida sem Escola Sabatina', () {
    final state = RemoteProtocol.parse(const RemotePlayerState(playing: false, position: Duration.zero, duration: Duration.zero, slideIndex: 0, slideCount: 0, volume: 80, canPrevious: false, canNext: false).encode()) as RemotePlayerState;
    expect(state.sabbathModule, isNull);
  });
}
