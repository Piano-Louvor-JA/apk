import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_slide_gallery.dart';

RemotePlayerState background(String key, List<String>? sources) =>
    RemotePlayerState(
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      slideIndex: 0,
      slideCount: 1,
      volume: 100,
      canPrevious: false,
      canNext: false,
      slideBackgroundKey: key,
      slideBackgroundSources: sources,
      slideBackgroundIndex: const [0],
    );
void main() {
  test('fundos local e remoto permanecem disponíveis ao alternar painéis', () {
    RemoteSlideGallery.reset();
    final remote = background('desktop', ['https://example.test/remote.jpg']);
    final local = background('local', ['https://example.test/local.jpg']);
    RemoteSlideGallery.remember(remote);
    RemoteSlideGallery.remember(local);
    expect(
      RemoteSlideGallery.background(background('desktop', null), 0),
      'https://example.test/remote.jpg',
    );
    expect(
      RemoteSlideGallery.background(local, 0),
      'https://example.test/local.jpg',
    );
  });
}
