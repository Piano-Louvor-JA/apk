import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';

void main() {
  test('avisa uma vez quando a faixa preparada começa a tocar', () {
    final notifier = NowPlayingNotifier();
    var calls = 0;
    notifier.start(hymnId: 7, title: 'Digno', album: '');
    notifier.setPlaying(false);
    whenTrackStarts(notifier, 7, () => calls++);
    expect(calls, 0);
    notifier.setPlaying(true);
    notifier.setPlaying(false);
    notifier.setPlaying(true);
    expect(calls, 1);
  });

  test('outra faixa no lugar cancela o aviso', () {
    final notifier = NowPlayingNotifier();
    var calls = 0;
    notifier.start(hymnId: 7, title: 'Digno', album: '');
    notifier.setPlaying(false);
    whenTrackStarts(notifier, 7, () => calls++);
    notifier.start(hymnId: 8, title: 'Outro', album: '');
    notifier.stop();
    notifier.start(hymnId: 7, title: 'Digno', album: '');
    expect(calls, 0);
  });
}
