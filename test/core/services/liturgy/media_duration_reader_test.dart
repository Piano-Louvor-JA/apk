library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/media_duration_reader.dart';

void main() {
  // b-cdn.mp4 real: 567.262ms (confirmado via ffprobe)
  test('mp4 real lê duração próxima do ffprobe', () async {
    const path = '/media/rafaelejosi/NovoVolume/nvme-mint/Downloads/b-cdn.mp4';
    if (!File(path).existsSync()) {
      // ignore: avoid_print
      print('skip: arquivo de teste ausente');
      return;
    }
    final ms = await MediaDurationReader.readMs(path);
    expect(ms, inInclusiveRange(560000, 575000));
  });

  test('arquivo inexistente → 0', () async {
    expect(await MediaDurationReader.readMs('/nao/existe.mp4'), 0);
  });

  test('arquivo não-mp4 → 0 sem lançar', () async {
    final tmp = File(
      '/tmp/teste_duracao_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await tmp.writeAsString('não é mp4');
    expect(await MediaDurationReader.readMs(tmp.path), 0);
    await tmp.delete();
  });
}
