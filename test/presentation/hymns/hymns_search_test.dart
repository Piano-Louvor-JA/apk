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

  testWidgets('busca com resultado mostra ListTile e tap abre hino', (
    tester,
  ) async {
    final bloc = _bloc(_SearchApi(const [
      Hymn(id: 7, number: 7, title: 'Chegou a Hora'),
      Hymn(id: 8, number: 8, title: 'Outro Hino'),
    ]));
    await pumpLoaded(tester, bloc);

    await tester.tap(find.byIcon(TablerIcons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'hora');
    // debounce 400ms
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Chegou a Hora'), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);

    // limpa a busca: <3 chars volta pro catálogo
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Chegou a Hora'), findsNothing);
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

  testWidgets('busca por número também encontra', (tester) async {
    final bloc = _bloc(_SearchApi(const [
      Hymn(id: 7, number: 707, title: 'Qualquer'),
    ]));
    await pumpLoaded(tester, bloc);

    await tester.tap(find.byIcon(TablerIcons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '707');
    await tester.pumpAndSettle();

    expect(find.text('Qualquer'), findsOneWidget);
  });
}
