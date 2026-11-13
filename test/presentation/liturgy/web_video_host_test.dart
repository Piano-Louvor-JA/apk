import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_video.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/youtube_web.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/web_video_host.dart';

class _Web implements LiturgyWebVideo {
  int views = 0;
  @override
  Widget view() {
    views++;
    return const SizedBox(key: Key('page'));
  }

  @override
  Future<void> load(
    String url, {
    Map<String, String> headers = const {},
  }) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<YoutubeWebState?> probe() async => null;
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('um só player: segue o espaço visível e estaciona sem nenhum', (
    tester,
  ) async {
    final slots = WebVideoSlots();
    final web = _Web();
    final showSmall = ValueNotifier(true);
    final showBig = ValueNotifier(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: showSmall,
              builder: (_, on, _) => Positioned(
                left: 10,
                top: 20,
                width: 112,
                height: 72,
                child: on ? WebVideoSlot(slots: slots) : const SizedBox(),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: showBig,
              builder: (_, on, _) => Positioned(
                left: 0,
                top: 300,
                width: 320,
                height: 180,
                child: on ? WebVideoSlot(slots: slots) : const SizedBox(),
              ),
            ),
            WebVideoLayer(video: web, slots: slots),
          ],
        ),
      ),
    );
    await tester.pump();
    final element = tester.element(find.byKey(const Key('page')));
    expect(
      tester.getRect(find.byKey(const Key('web-video-layer'))),
      const Rect.fromLTWH(10, 20, 112, 72),
    );

    // Expandir: o mesmo player vai para o espaço grande.
    showBig.value = true;
    showSmall.value = false;
    await tester.pump();
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const Key('web-video-layer'))),
      const Rect.fromLTWH(0, 300, 320, 180),
    );

    // Nenhum espaço: estacionado em 1 px, ainda montado.
    showBig.value = false;
    await tester.pump();
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const Key('web-video-layer'))),
      const Rect.fromLTWH(0, 0, 1, 1),
    );
    // Mesmo elemento o tempo todo: a WebView nunca foi remontada.
    expect(tester.element(find.byKey(const Key('page'))), same(element));
    expect(web.views, 1);
  });
}
