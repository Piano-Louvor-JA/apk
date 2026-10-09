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

  test('mp4 sintético v0 em moov lê duração calculada', () async {
    final tmp = File(
      '/tmp/teste_duracao_v0_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    // ftyp (16B) + moov{mvhd v0: timescale=1000, duration=1500 → 1500ms}
    final bytes = <int>[
      ...[0, 0, 0, 16], ...'ftyp'.codeUnits, ...'isom'.codeUnits, 0, 0, 0, 0,
      ...[0, 0, 0, 36], ...'moov'.codeUnits,
      ...[0, 0, 0, 28], ...'mvhd'.codeUnits, 0, // version 0
      0, 0, 0, // flags
      0, 0, 0, 0, // ctime
      0, 0, 0, 0, // mtime
      0, 0, 3, 232, // timescale = 1000
      0, 0, 5, 220, // duration = 1500
      0, 0, 0, 0, // rate
    ];
    await tmp.writeAsBytes(bytes);
    expect(await MediaDurationReader.readMs(tmp.path), 1500);
    await tmp.delete();
  });

  test('mp4 sintético v1 lê duração 64-bit e atom vazio retorna 0', () async {
    final tmp = File(
      '/tmp/teste_duracao_v1_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    // moov{mvhd v1: timescale=10, duration=30 → 3000ms}
    // mvhd v1: size(4)+type(4)+version(1)+flags(3)+ctime(8)+mtime(8)
    //          +timescale(4)+duration(8)+rate(4) = 44+8 = 52 → 0x34
    final bytes = <int>[
      ...[0, 0, 0, 52], ...'moov'.codeUnits,
      ...[0, 0, 0, 44], ...'mvhd'.codeUnits, 1, // version 1
      0, 0, 0, // flags
      0, 0, 0, 0, 0, 0, 0, 0, // ctime
      0, 0, 0, 0, 0, 0, 0, 0, // mtime
      0, 0, 0, 10, // timescale = 10
      0, 0, 0, 0, 0, 0, 0, 30, // duration = 30 (v1 offset real)
      0, 0, 0, 0, // rate
    ];
    await tmp.writeAsBytes(bytes);
    expect(await MediaDurationReader.readMs(tmp.path), 3000);
    await tmp.delete();

    final empty = File(
      '/tmp/teste_duracao_vazio_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    await empty.writeAsBytes([0, 0, 0, 0]);
    expect(await MediaDurationReader.readMs(empty.path), 0);
    await empty.delete();
  });
}
