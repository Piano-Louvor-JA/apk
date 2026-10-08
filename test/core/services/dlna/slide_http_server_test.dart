import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/slide_http_server.dart';

/// Fluxo HTTP cru (GET/HEAD contra o server) é coberto em device/integration —
/// o flutter_tester intercepta HttpClient e devolve 400 sintético, então
/// aqui exercitamos só o ciclo de vida e a geração de URL.
void main() {
  late SlideHttpServer server;

  setUp(() async {
    server = SlideHttpServer();
    SlideHttpServer.rendererSubnetHint = null;
  });

  tearDown(() async {
    await server.stop();
    SlideHttpServer.rendererSubnetHint = null;
  });

  test('start sobe servidor e devolve URL http da LAN', () async {
    final base = await server.start();
    expect(base, isNotNull);
    expect(base, startsWith('http://'));
    expect(server.isRunning, isTrue);
    expect(server.port, greaterThan(0));
  });

  test('stop para o servidor e isRunning false', () async {
    await server.start();
    await server.stop();
    expect(server.isRunning, isFalse);
  });

  test('stop sem start não lança', () async {
    await server.stop();
    expect(server.isRunning, isFalse);
  });

  test('serveSlide sem start retorna null', () async {
    final u = await server.serveSlide(Uint8List.fromList([1]));
    expect(u, isNull);
  });

  test('serveSlide gera URL com counter crescente (cache bust)', () async {
    await server.start();
    final u1 = await server.serveSlide(Uint8List.fromList([1]));
    final u2 = await server.serveSlide(Uint8List.fromList([2]), jpeg: true);

    expect(u1, isNotNull);
    expect(u2, isNotNull);
    expect(u1, contains('/slide.png?v='));
    expect(u2, contains('/slide.jpg?v='));
    expect(u1 != u2, isTrue);
  });

  test('serveSlide jpeg=true muda extensão para .jpg', () async {
    await server.start();
    final u = await server.serveSlide(Uint8List.fromList([7]), jpeg: true);
    expect(u, contains('.jpg?v='));
  });
}
