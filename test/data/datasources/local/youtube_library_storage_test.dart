import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/youtube_library_storage.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

const a = YoutubeVideo(
  videoId: 'AAAAAAAAAAA',
  title: 'Meu Pastor',
  channel: 'Arautos do Rei',
  durationText: '4:12',
);
const b = YoutubeVideo(videoId: 'BBBBBBBBBBB', title: 'Vox - Hino 2');
const c = YoutubeVideo(videoId: 'CCCCCCCCCCC', title: 'Três');

void main() {
  late int now;
  late YoutubeLibraryStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = 1000;
    storage = YoutubeLibraryStorage(clock: () => now);
  });

  group('histórico', () {
    test('tocar sobe para o topo e soma reproduções (sobrevive a reload)', () async {
      await storage.recordPlay(a);
      now = 2000;
      await storage.recordPlay(b);
      now = 3000;
      await storage.recordPlay(const YoutubeVideo(videoId: 'AAAAAAAAAAA', title: ''));
      final reloaded = await YoutubeLibraryStorage().history();
      expect(reloaded.map((e) => e.videoId), ['AAAAAAAAAAA', 'BBBBBBBBBBB']);
      expect(reloaded.first.playCount, 2);
      expect(reloaded.first.title, 'Meu Pastor');
      expect(reloaded.first.channel, 'Arautos do Rei');
      expect(reloaded.first.at, 3000);
    });

    test('id inválido não entra; remover e limpar', () async {
      await storage.recordPlay(const YoutubeVideo(videoId: 'curto', title: 'x'));
      expect(await storage.history(), isEmpty);
      await storage.recordPlay(a);
      await storage.recordPlay(b);
      expect((await storage.removeFromHistory('AAAAAAAAAAA')).length, 1);
      expect(await storage.clearHistory(), isEmpty);
    });

    test('dado salvo inválido ou corrompido é descartado', () async {
      SharedPreferences.setMockInitialValues({
        YoutubeLibraryStorage.historyKey: jsonEncode([
          {'videoId': 'AAAAAAAAAAA', 'title': 'Um', 'playedAt': 5},
          {'videoId': 'AAAAAAAAAAA', 'title': 'Repetido', 'playedAt': 9},
          {'videoId': 'x'},
          'lixo',
        ]),
        YoutubeLibraryStorage.favoritesKey: '{quebrado',
      });
      final list = await YoutubeLibraryStorage().history();
      expect(list.single.title, 'Um');
      expect(list.single.playCount, 1);
      expect(await YoutubeLibraryStorage().favorites(), isEmpty);
    });

    test('guarda no máximo 300', () async {
      for (var i = 0; i < 305; i++) {
        now = i;
        await storage.recordPlay(
          YoutubeVideo(videoId: 'V${i.toString().padLeft(10, '0')}', title: '$i'),
        );
      }
      expect((await storage.history()).length, YoutubeLibraryStorage.historyMax);
    });
  });

  test('buscas recentes: mais recente primeiro, sem repetir, até 10', () async {
    await storage.rememberQuery('Arautos do rei');
    await storage.rememberQuery('Adoradores');
    await storage.rememberQuery('  arautos DO REI ');
    await storage.rememberQuery('   ');
    expect(await storage.recentQueries(), ['arautos DO REI', 'Adoradores']);
    for (var i = 0; i < 12; i++) {
      await storage.rememberQuery('q$i');
    }
    expect((await storage.recentQueries()).length, 10);
    expect(await storage.forgetQuery('q11'), isNot(contains('q11')));
  });

  test('favoritos: liga e desliga, novo no topo', () async {
    await storage.toggleFavorite(a);
    await storage.toggleFavorite(b);
    expect((await storage.favorites()).map((e) => e.videoId), [
      'BBBBBBBBBBB',
      'AAAAAAAAAAA',
    ]);
    await storage.toggleFavorite(a);
    expect((await YoutubeLibraryStorage().favorites()).single.videoId, 'BBBBBBBBBBB');
    await storage.toggleFavorite(const YoutubeVideo(videoId: 'x', title: 'x'));
    expect((await storage.favorites()).length, 1);
  });

  group('coletâneas', () {
    test('criar, renomear e excluir (sobrevive a reload)', () async {
      final created = await storage.createCollection('  Hinos   de Natal ');
      expect(created.created!.name, 'Hinos de Natal');
      expect((await storage.createCollection('   ')).created, isNull);
      final id = created.created!.id;
      now = 5000;
      await storage.renameCollection(id, 'Natal 2026');
      final reloaded = await YoutubeLibraryStorage().collections();
      expect(reloaded.single.name, 'Natal 2026');
      expect(reloaded.single.updatedAt, 5000);
      expect(await storage.deleteCollection(id), isEmpty);
    });

    test('adicionar sem repetir, remover e mover', () async {
      final id = (await storage.createCollection('Culto')).created!.id;
      await storage.addVideo(id, a);
      await storage.addVideos(id, [a, b, c, const YoutubeVideo(videoId: 'x', title: '')]);
      var list = await storage.collections();
      expect(list.single.videos.map((v) => v.videoId), [
        'AAAAAAAAAAA',
        'BBBBBBBBBBB',
        'CCCCCCCCCCC',
      ]);
      list = await storage.moveVideo(id, 'CCCCCCCCCCC', -1);
      expect(list.single.videos[1].videoId, 'CCCCCCCCCCC');
      list = await storage.moveVideo(id, 'AAAAAAAAAAA', -1);
      expect(list.single.videos.first.videoId, 'AAAAAAAAAAA');
      list = await storage.removeVideo(id, 'AAAAAAAAAAA');
      expect(list.single.videos.length, 2);
      expect(list.single.has('AAAAAAAAAAA'), isFalse);
      final untouched = await storage.addVideo('nao-existe', a);
      expect(untouched.single.videos.length, 2);
    });
  });

  test('filtro sem acento e com todos os termos', () {
    final list = [a, b, c];
    String text(YoutubeVideo v) => '${v.title} ${v.channel}';
    expect(filterYoutubeVideos(list, 'arautos pástor', text), [a]);
    expect(filterYoutubeVideos(list, '  ', text), list);
    expect(filterYoutubeVideos(list, 'nada', text), isEmpty);
  });
}
