library;

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/errors/louvorja_api_exception.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/catalog_cache.dart';
import 'package:louvorja_piano_mobile/data/repositories/hymn_repository_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/album_category.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_version.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/repositories/louvorja_api_client.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/bloc/hymns_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/hymns_page.dart';

/// Loader inline dos JSON reais (padrao dos outros widget tests).
class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      (jsonDecode(File('assets/translations/en.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>();
}

/// Mock que lanca 404 (errors.notFound) enquanto o prefixo != pt e
/// entrega catalogo quando o convite faz o override pt.
class _ApiInviteThenPt implements LouvorjaApiClient {
  @override
  String languagePrefix = 'it';

  @override
  Future<List<AlbumCategory>> fetchCategories() async {
    if (languagePrefix != 'pt') {
      throw const LouvorjaApiException('errors.notFound', 'sem catalogo');
    }
    return const [AlbumCategory(id: 1, name: 'Vozes', albums: [])];
  }

  @override
  Future<List<Hymn>> fetchAlbumHymns(int albumId) async => const [];
  @override
  Future<Hymn> fetchMusic(int musicId) async => Hymn(id: musicId);
  @override
  Future<List<Hymn>> fetchHymnal() async => const [];
  @override
  Future<List<Hymn>> fetchHymnal1996() async => const [];
  @override
  Future<List<Hymn>> fetchMusicIndex() async => const [];
  @override
  String resolveMediaUrl(String p) => p;
  @override
  Future<List<BibleBook>> fetchBibleBooks() async => const [];
  @override
  Future<List<BibleVersion>> fetchBibleVersions() async => const [];
  @override
  Future<Map<String, String>> fetchBibleChapter(int v, int b, int c) async =>
      {};
}

Future<void> _pump(WidgetTester tester, HymnsBloc bloc) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      assetLoader: const _Translations(),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: HymnsPage(testBloc: bloc),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  // Sem pumpAndSettle: a aba Hinos mantem animacoes continuas
  // (indicadores de progresso indeterminados) que nunca assentam.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('convite: 404 mostra seedling+titulo+botao pt (nao wifi-off)',
      (tester) async {
    final api = _ApiInviteThenPt();
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);
    bloc.add(HymnsLoadRequested());

    await _pump(tester, bloc);

    // Nao e tela de erro: sem icone wifiOff.
    expect(find.byIcon(Icons.wifi_off), findsNothing);

    // Convite: card + textos traduzidos + botao pt.
    expect(find.byKey(const Key('hymns-catalog-invite')), findsOneWidget);
    expect(find.text('Catalog under construction'), findsOneWidget);
    expect(
      find.text(
        'The music catalog is not yet available in your language. '
        'Join the community and help build the LouvorJA catalog in your '
        'own language.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('hymns-invite-see-pt')), findsOneWidget);
    // Sem close() explicito: fechar com o widget ainda escutando trava
    // o testWidgets (diagnostico local); o framework desmonta a arvore.
  });

  testWidgets('convite: botao "Ver em Portugues" troca so o catalogo',
      (tester) async {
    final api = _ApiInviteThenPt();
    final repo = HymnRepositoryImpl(api, CatalogCache.noop());
    final bloc = HymnsBloc(repo);
    bloc.add(HymnsLoadRequested());

    await _pump(tester, bloc);
    expect(find.byKey(const Key('hymns-catalog-invite')), findsOneWidget);

    // Botao faz override pt SOMENTE do catalogo (UI continua em ingles).
    await tester.tap(find.byKey(const Key('hymns-invite-see-pt')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('hymns-catalog-invite')), findsNothing);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
    expect(api.languagePrefix, 'pt');
    expect(bloc.state, isA<HymnsLoaded>());
  });
}
