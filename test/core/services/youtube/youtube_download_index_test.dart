import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_download_index.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

const a = YoutubeVideo(
  videoId: 'AAAAAAAAAAA',
  title: 'Arautos do Rei | 60 Anos',
  channel: 'Arautos',
  thumbnail: 't.jpg',
  durationText: '3:11',
);
const b = YoutubeVideo(videoId: 'BBBBBBBBBBB', title: 'Vox');

void main() {
  late int now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = 10;
  });

  YoutubeDownloadIndex make() => YoutubeDownloadIndex(clock: () => now);

  test(
    'registra o baixado com o nome automático (sobrevive a reabrir)',
    () async {
      await make().remember(a);
      now = 20;
      await make().remember(b);
      final list = await make().entries();
      expect(list.map((e) => e.videoId), [b.videoId, a.videoId]);
      final entry = list.last;
      expect(entry.fileName, 'Arautos do Rei 60 Anos_${a.videoId}.mp4');
      expect(entry.renamed, isFalse);
      expect(entry.at, 10);
      expect(entry.video.channel, 'Arautos');
    },
  );

  test('renomear limpa o nome, guarda e marca como renomeado', () async {
    final index = make();
    await index.remember(a);
    expect(
      await index.rename(a.videoId, 'Abertura — sábado / 19h!'),
      'Abertura sabado 19h_${a.videoId}.mp4',
    );
    var entry = (await make().entries()).single;
    expect(entry.renamed, isTrue);
    expect(entry.fileName, 'Abertura sabado 19h_${a.videoId}.mp4');

    // Registrar de novo (baixou de novo) mantém o nome dado.
    await index.remember(const YoutubeVideo(videoId: 'AAAAAAAAAAA', title: ''));
    entry = (await make().entries()).single;
    expect(entry.fileName, 'Abertura sabado 19h_${a.videoId}.mp4');
    expect(entry.video.title, a.title);

    // Voltar ao nome automático deixa de contar como renomeado.
    await index.rename(a.videoId, a.title);
    expect((await make().entries()).single.renamed, isFalse);
    expect(await index.rename('CCCCCCCCCCC', 'x'), isNull);
  });

  test('esquecer e ordem da aba', () async {
    final index = make();
    await index.remember(a);
    await index.remember(b);
    await index.forget(a.videoId);
    await index.forget('CCCCCCCCCCC');
    expect((await index.entries()).map((e) => e.videoId), [b.videoId]);
    expect(await index.order(), isEmpty);
    await index.saveOrder([b.videoId, a.videoId]);
    expect(await make().order(), [b.videoId, a.videoId]);
  });

  test(
    'download concluído junto de renomear preserva os dois dados ao reabrir',
    () async {
      final index = make();
      await index.remember(a);
      await Future.wait([
        index.rename(a.videoId, 'Abertura do culto'),
        index.remember(b),
      ]);
      final reopened = await make().entries();
      expect(
        reopened.map((e) => e.videoId),
        containsAll([a.videoId, b.videoId]),
      );
      expect(
        reopened.singleWhere((e) => e.videoId == a.videoId).fileName,
        'Abertura do culto_${a.videoId}.mp4',
      );
    },
  );

  test('dado salvo inválido ou corrompido é descartado', () async {
    SharedPreferences.setMockInitialValues({
      YoutubeDownloadIndex.entriesKey: jsonEncode([
        {'videoId': 'AAAAAAAAAAA', 'title': '', 'name': '../fora', 'at': 'x'},
        {'videoId': 'AAAAAAAAAAA', 'title': 'Repetido'},
        {'videoId': 'x'},
        'lixo',
      ]),
      YoutubeDownloadIndex.orderKey: '{quebrado',
    });
    final entry = (await make().entries()).single;
    expect(entry.video.title, 'AAAAAAAAAAA');
    expect(entry.fileName, 'AAAAAAAAAAA.mp4');
    expect(entry.at, 0);
    expect(await make().order(), isEmpty);
    SharedPreferences.setMockInitialValues({
      YoutubeDownloadIndex.entriesKey: '{"x":1}',
    });
    expect(await make().entries(), isEmpty);
  });
}
