library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

/// F3.4: o APK serve o receiver em `/` — qualquer dispositivo na rede
/// (browser do PC/celular) abre `http://<ip>:7080/` e vira Palco de teste.
///
/// HTTP via socket TCP cru: o TestWidgetsFlutterBinding bloqueia HttpClient
/// (retorna 400 fake), mas socket direto passa.
void main() {
  test('GET / e /receiver.html servem a página do receiver (asset)', () async {
    const fakeHtml =
        '<!DOCTYPE html><html><body>PALCO RECEIVER TEST</body></html>';
    final sender = PalcoSender(
      httpPortFixed: 0,
      wsPortFixed: 0,
      receiverPage: Uint8List.fromList(utf8.encode(fakeHtml)),
    );
    final base = await sender.start();
    expect(base, isNotNull);
    final port = sender.effectiveHttpPort;

    for (final path in ['/', '/receiver.html']) {
      final socket = await Socket.connect('127.0.0.1', port);
      socket.write(
        'GET $path HTTP/1.1\r\nHost: 127.0.0.1\r\n'
        'Connection: close\r\n\r\n',
      );
      final data = await socket.fold<List<int>>(
        <int>[],
        (acc, d) => acc..addAll(d as List<int>),
      );
      await socket.close();
      final text = utf8.decode(data);
      expect(text, startsWith('HTTP/1.1 200'), reason: 'GET $path');
      expect(text, contains('text/html'));
      expect(text, contains('PALCO RECEIVER TEST'));
    }

    await sender.stop();
  });
}
