import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';

class Api extends Mock implements LouvorjaApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(LiturgyCatalogRepository.resetSessionIndex);
  test('livros, versões e capítulos da Liturgia reabrem sem rede', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = Api();
    when(() => api.fetchBibleBooks()).thenAnswer(
      (_) async => [
        const BibleBook(
          id: 1,
          name: 'Gênesis',
          abbreviation: 'Gn',
          chapters: 50,
          bookNumber: 1,
        ),
      ],
    );
    when(() => api.fetchBibleVersions()).thenAnswer(
      (_) async => [
        const BibleVersion(id: 13, abbreviation: 'ARA', name: 'Almeida'),
      ],
    );
    when(
      () => api.fetchBibleChapter(13, 1, 1),
    ).thenAnswer((_) async => {'1': 'No princípio'});
    final online = LiturgyCatalogRepository(prefs, api);
    expect((await online.getBooks()).single.id, 1);
    expect((await online.getVersions()).single.id, 13);
    expect((await online.getChapter(13, 1, 1))['1'], 'No princípio');
    final offline = LiturgyCatalogRepository(prefs, Api());
    expect((await offline.getBooks()).single.name, 'Gênesis');
    expect((await offline.getVersions()).single.abbreviation, 'ARA');
    expect((await offline.getChapter(13, 1, 1))['1'], 'No princípio');
  });
  test(
    'índice e detalhe ficam disponíveis offline após reabrir, isolados por idioma',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = Api();
      when(
        () => api.fetchMusicIndex(),
      ).thenAnswer((_) async => [const Hymn(id: 42, title: 'Hino')]);
      when(() => api.fetchMusic(42)).thenAnswer(
        (_) async => const Hymn(
          id: 42,
          title: 'Hino',
          urlMusic: 'vocal.mp3',
          lyric: 'Texto',
          durationMs: 187500,
          albumIds: [2, 3],
          hymnalTracks: [42, 100],
        ),
      );
      final repo = LiturgyCatalogRepository(prefs, api, locale: 'pt');
      expect((await repo.musicIndex()).single.id, 42);
      expect((await repo.music(42)).lyric, 'Texto');
      final unavailable = Api();
      when(
        () => unavailable.fetchMusicIndex(),
      ).thenThrow(Exception('sem rede'));
      LiturgyCatalogRepository.resetSessionIndex();
      final offline = LiturgyCatalogRepository(
        prefs,
        unavailable,
        locale: 'pt',
      );
      expect((await offline.musicIndex()).single.id, 42);
      expect((await offline.music(42)).lyric, 'Texto');
      expect((await offline.music(42)).durationMs, 187500);
      expect((await offline.music(42)).albumIds, [2, 3]);
      expect((await offline.music(42)).hymnalTracks, [42, 100]);
      verifyNever(() => unavailable.fetchMusic(42));
      expect(
        LiturgyCatalogRepository(
          prefs,
          unavailable,
          locale: 'es',
        ).cachedMusic(42),
        isNull,
      );
    },
  );

  test(
    'índice gravado antes (outra API, catálogo menor) é atualizado pela rede',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final old = Api();
      when(
        () => old.fetchMusicIndex(),
      ).thenAnswer((_) async => [const Hymn(id: 1, title: 'Digno')]);
      await LiturgyCatalogRepository(prefs, old).musicIndex();
      LiturgyCatalogRepository.resetSessionIndex();

      final api = Api();
      when(() => api.fetchMusicIndex()).thenAnswer(
        (_) async => [
          const Hymn(id: 1, title: 'Digno'),
          const Hymn(id: 2, title: 'Tu És Digno'),
          const Hymn(id: 3, title: 'Digno de Louvor'),
        ],
      );
      final repo = LiturgyCatalogRepository(prefs, api);
      expect(await repo.musicIndex(), hasLength(3));
      // Mesma sessão: não busca de novo a cada abertura da busca.
      expect(
        await LiturgyCatalogRepository(prefs, api).musicIndex(),
        hasLength(3),
      );
      verify(() => api.fetchMusicIndex()).called(1);
    },
  );
}
