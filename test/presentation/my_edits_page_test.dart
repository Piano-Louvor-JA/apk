// MyEditsPage — Minhas Edições read-only (portação APK, padrão F0: APK consome).
// Padrão de EasyLocalization copiado de offline_banner_test.dart (singleton global).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/edits_api_impl.dart';
import 'package:louvorja_piano_mobile/presentation/community/my_edits_page.dart';

class _MockDio extends Mock implements Dio {}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'myEdits': {
          'title': 'Minhas Edições',
          'empty': 'Nenhuma edição publicada ainda.',
          'musicLabel': 'Música #{id}',
          'statusApproved': 'Aprovada',
          'statusRejected': 'Rejeitada',
          'statusPublished': 'Publicada',
        },
      };
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('pt', 'BR')],
      path: 'assets/translations',
      assetLoader: const _Translations(),
      startLocale: const Locale('pt', 'BR'),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

MyEditsPage _page(_MockDio dio) => MyEditsPage(
      api: EditsApiImpl(
        dio: dio,
        apiBaseUrl: 'https://api.test',
        bearerToken: () async => 'tok',
      ),
    );

void main() {
  late _MockDio dio;

  setUp(() {
    dio = _MockDio();
    registerFallbackValue(RequestOptions(path: ''));
  });

  void stub(Response<dynamic> response) {
    when(() => dio.request<dynamic>(any(),
        data: any(named: 'data'),
        options: any(named: 'options'))).thenAnswer((_) async => response);
  }

  testWidgets('lista edits com status e motivo (RF-05)', (tester) async {
    stub(Response<List<dynamic>>(
      requestOptions: RequestOptions(path: ''),
      data: [
        {'id': 1, 'music_id': 42, 'status': 'approved', 'reason': null},
        {
          'id': 2,
          'music_id': 77,
          'status': 'rejected',
          'reason': 'letra diverge da fonte oficial',
        },
      ],
    ));

    await _pump(tester, _page(dio));
    await tester.pumpAndSettle();

    expect(find.text('Música #42'), findsOneWidget);
    expect(find.text('Música #77'), findsOneWidget);
    expect(find.textContaining('diverge'), findsOneWidget);
    expect(find.text('Aprovada'), findsOneWidget);
    expect(find.text('Rejeitada'), findsOneWidget);
  });

  testWidgets('lista vazia mostra estado vazio', (tester) async {
    stub(Response<List<dynamic>>(
      requestOptions: RequestOptions(path: ''),
      data: <dynamic>[],
    ));

    await _pump(tester, _page(dio));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma edição publicada ainda.'), findsOneWidget);
  });

  testWidgets('NENHUM botão de editar/publicar (read-only, decisão F0)',
      (tester) async {
    stub(Response<List<dynamic>>(
      requestOptions: RequestOptions(path: ''),
      data: [
        {'id': 1, 'music_id': 42, 'status': 'published', 'reason': null},
      ],
    ));

    await _pump(tester, _page(dio));
    await tester.pumpAndSettle();

    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('erro de rede mostra estado vazio sem quebrar', (tester) async {
    when(() => dio.request<dynamic>(any(),
        data: any(named: 'data'),
        options: any(named: 'options'))).thenThrow(DioException(
      requestOptions: RequestOptions(path: ''),
    ));

    await _pump(tester, _page(dio));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma edição publicada ainda.'), findsOneWidget);
  });
}
