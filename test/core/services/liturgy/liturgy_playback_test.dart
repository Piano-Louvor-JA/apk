import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_playback.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

class Api extends Mock implements LouvorjaApiClient {}

class Offline extends Mock implements OfflineMusicPort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'áudio offline conserva capa e slides ao obter o detalhe completo',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = Api();
      final offline = Offline();
      when(() => offline.isSupported).thenReturn(true);
      when(
        () => offline.localPathFor(42, instrumental: false),
      ).thenAnswer((_) async => '/offline/42.mp3');
      when(() => api.fetchMusic(42)).thenAnswer(
        (_) async => const Hymn(
          id: 42,
          title: 'Tu És Digno',
          imageUrl: 'images/capa.jpg',
          lyricRaw: [
            {
              'lyric': 'Tu és digno',
              'url_image': 'images/fundo.jpg',
              'show_slide': 1,
              'order': 1,
            },
          ],
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final result = await LiturgyPlayback.resolve(
        const LiturgyItem(
          id: 'm',
          type: LiturgyItemType.music,
          name: 'Tu És Digno',
          musicId: 42,
        ),
        catalog: LiturgyCatalogRepository(prefs, api),
        offline: offline,
      );
      expect(result.source, '/offline/42.mp3');
      expect(result.isLocal, isTrue);
      expect(result.detail.imageUrl, 'images/capa.jpg');
      expect(result.detail.lyricRaw!.single['url_image'], 'images/fundo.jpg');
      final cached = LiturgyCatalogRepository(prefs, Api()).cachedMusic(42)!;
      expect(cached.imageUrl, 'images/capa.jpg');
      expect(cached.lyricRaw, isNotEmpty);
    },
  );
  test(
    'arquivo local continua tocando quando os metadados estão indisponíveis',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = Api();
      final offline = Offline();
      when(() => api.fetchMusic(42)).thenThrow(StateError('offline'));
      when(() => offline.isSupported).thenReturn(true);
      when(
        () => offline.localPathFor(42, instrumental: true),
      ).thenAnswer((_) async => '/offline/42i.mp3');
      final result = await LiturgyPlayback.resolve(
        const LiturgyItem(
          id: 'x',
          type: LiturgyItemType.music,
          name: 'Hino',
          musicId: 42,
          musicMode: 'instrumental',
        ),
        catalog: LiturgyCatalogRepository(
          await SharedPreferences.getInstance(),
          api,
        ),
        offline: offline,
      );
      expect(result.source, '/offline/42i.mp3');
      expect(result.isLocal, isTrue);
      expect(result.detail.title, 'Hino');
      verify(() => api.fetchMusic(42)).called(1);
    },
  );
  test('stream seleciona a URL do modo explícito do item', () async {
    SharedPreferences.setMockInitialValues({});
    final api = Api();
    final offline = Offline();
    when(() => offline.isSupported).thenReturn(false);
    when(() => api.fetchMusic(42)).thenAnswer(
      (_) async => const Hymn(
        id: 42,
        urlMusic: 'https://example.org/vocal.mp3',
        urlInstrumental: 'https://example.org/instrumental.mp3',
      ),
    );
    final result = await LiturgyPlayback.resolve(
      const LiturgyItem(
        id: 'x',
        type: LiturgyItemType.music,
        name: 'Hino',
        musicId: 42,
        musicMode: 'instrumental',
      ),
      catalog: LiturgyCatalogRepository(
        await SharedPreferences.getInstance(),
        api,
      ),
      offline: offline,
    );
    expect(result.source, 'https://example.org/instrumental.mp3');
    expect(result.isLocal, isFalse);
  });
}
