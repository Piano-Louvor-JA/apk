library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/hymns_page.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';

class _SearchApi implements LouvorjaApiClient {
  @override
  String languagePrefix = 'pt';

  final List<Hymn> index;
  _SearchApi(this.index);

  @override
  Future<List<Hymn>> fetchMusicIndex() async => index;
  @override
  Future<List<AlbumCategory>> fetchCategories() async => const [];
  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async => const [];
  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  String resolveMediaUrl(String relativePath) => '';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

HymnsBloc _bloc(LouvorjaApiClient api) =>
    HymnsBloc(HymnRepositoryImpl(api, CatalogCache.noop()));

/// Onda 84: busca da HymnsPage — debounce, loading, resultados, vazio e
/// limpar campo (<3 chars) voltando ao catálogo.
void main() {
  Future<void> pumpLoaded(WidgetTester tester, HymnsBloc bloc) async {
    bloc.add(HymnsLoadRequested());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HymnsBloc>.value(
          value: bloc,
          child: HymnsPage(testBloc: bloc),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.tap(find.byIcon(TablerIcons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), query);
  }

  testWidgets('busca com resultado mostra tile completo e dica de critério', (
    tester,
  ) async {
    final bloc = _bloc(
      _SearchApi(const [
        Hymn(
          id: 7,
          number: 7,
          title: 'Chegou a Hora',
          durationMs: 125000,
          albumNames: 'Coletânea Alfa',
          albumIds: [11],
          hymnalTracks: [7],
        ),
        Hymn(id: 8, number: 8, title: 'Outro Hino'),
      ]),
    );
    await pumpLoaded(tester, bloc);

    await search(tester, 'hora');
    // debounce 400ms
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    // Dica de critério é o primeiro item da lista.
    expect(find.text('hymns.searchCriteria'), findsOneWidget);
    expect(find.text('Chegou a Hora'), findsOneWidget);
    expect(find.text('Outro Hino'), findsNothing);
    expect(find.text('7'), findsOneWidget); // nº do hinário
    expect(find.text('Coletânea Alfa'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(find.byKey(const Key('search-add-playlist-7')), findsOneWidget);

    // limpa a busca: <3 chars volta pro catálogo
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Chegou a Hora'), findsNothing);
    expect(find.text('hymns.searchCriteria'), findsNothing);
  });

  testWidgets('tocar num resultado só toca (não abre NowPlayingPage)', (
    tester,
  ) async {
    final bloc = _bloc(
      _SearchApi(const [Hymn(id: 7, number: 7, title: 'Chegou a Hora')]),
    );
    await pumpLoaded(tester, bloc);

    await search(tester, 'hora');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chegou a Hora'));
    await tester.pumpAndSettle();

    // Sem rota nova: continua na lista de resultados.
    expect(find.byType(NowPlayingPage), findsNothing);
    expect(find.text('Chegou a Hora'), findsOneWidget);
    expect(find.text('hymns.searchCriteria'), findsOneWidget);
  });

  testWidgets('busca ignora acento e exige todos os termos; letra conta', (
    tester,
  ) async {
    final bloc = _bloc(
      _SearchApi(const [
        Hymn(id: 1, title: 'Ressurreição', albumNames: 'Páscoa'),
        Hymn(id: 2, title: 'Canto', lyric: 'jesus adoradores venham'),
        Hymn(id: 3, title: 'Outro', lyric: 'jesus apenas'),
      ]),
    );
    await pumpLoaded(tester, bloc);

    await search(tester, 'ressurreicao');
    await tester.pumpAndSettle();
    expect(find.text('Ressurreição'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jesus venham');
    await tester.pumpAndSettle();
    expect(find.text('Canto'), findsOneWidget);
    expect(find.text('Outro'), findsNothing);

    await tester.enterText(find.byType(TextField), 'pascoa');
    await tester.pumpAndSettle();
    expect(find.text('Ressurreição'), findsOneWidget);
  });

  testWidgets('busca sem resultado mostra estado vazio', (tester) async {
    final bloc = _bloc(_SearchApi(const [Hymn(id: 7, title: 'Nada aqui')]));
    await pumpLoaded(tester, bloc);

    await tester.tap(find.byIcon(TablerIcons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma musica encontrada'), findsOneWidget);
  });

  testWidgets('busca por número casa o nº do hinário, não id/número', (
    tester,
  ) async {
    final bloc = _bloc(
      _SearchApi(const [
        Hymn(id: 5, number: 5, title: 'Do Hinário', hymnalTracks: [707]),
        Hymn(id: 707, number: 707, title: 'Só pelo id'),
      ]),
    );
    await pumpLoaded(tester, bloc);

    await search(tester, '707');
    await tester.pumpAndSettle();

    expect(find.text('Do Hinário'), findsOneWidget);
    expect(find.text('Só pelo id'), findsNothing);
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('707')),
      findsOneWidget,
    );
  });
}
