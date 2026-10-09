library;

import 'dart:typed_data';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collections_page.dart';

/// Storage falso (mesmo do teste existente) pro auth não pendurar.
class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> backing = {};
  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.namedArguments;
    if (i.memberName == #write) {
      final v = n[#value] as String?;
      if (v == null) { backing.remove(n[#key] as String); } else { backing[n[#key] as String] = v; }
      return Future<void>.value();
    }
    if (i.memberName == #read) return Future<String?>.value(backing[n[#key] as String]);
    if (i.memberName == #delete) { backing.remove(n[#key] as String); return Future<void>.value(); }
    return null;
  }
}

CustomAuthController _fakeAuth() => CustomAuthController(
  CustomAuthApiImpl(
    fetch: (method, url, {body, bearerToken}) async => throw DioException(
      requestOptions: RequestOptions(path: url),
    ),
    apiBaseUrl: 'https://api.test',
    sessionStore: CustomSessionStore(storage: _FakeStorage()),
  ),
);

/// Onda 77: coletânea de OUTRO autor (is_owner=0, id>0) — download/remove
/// com FutureBuilder de joined ids + snackbar "somente leitura" no tap do
/// card. API falsa via adapter Dio; joined ids via SharedPreferences mock.
class _ApiAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> collections;
  _ApiAdapter(this.collections);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"data": ${jsonEncode(collections)}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const otherAuthor = {
    'id_collection': 42,
    'name': 'Harpa de Outrem',
    'author_name': 'Maria',
    'musics_count': 7,
    'is_owner': 0,
  };

  Future<void> pumpPage(WidgetTester tester) async {
    final dio = Dio()..httpClientAdapter = _ApiAdapter([otherAuthor]);
    await tester.pumpWidget(
      MaterialApp(home: CustomCollectionsPage(dio: dio, authController: _fakeAuth())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('coletânea de outro autor aparece com autor e botão baixar',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Harpa de Outrem'), findsOneWidget);
    expect(find.text('por Maria'), findsOneWidget);
    expect(find.byTooltip('Baixar'), findsOneWidget);
  });

  testWidgets('baixar coletânea: join + snack + ícone vira done', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Baixar'));
    await tester.pump();
    expect(find.textContaining('baixada!'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remover download'), findsOneWidget);
  });

  testWidgets('remover download: diálogo de confirmação + snack removido',
      (tester) async {
    // pré-baixada
    SharedPreferences.setMockInitialValues({'louvorja.custom.joined': ['42']});
    await pumpPage(tester);
    expect(find.byTooltip('Remover download'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover download'));
    await tester.pumpAndSettle();

    // diálogo de confirmação
    expect(find.textContaining('Remover download de'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.pump();
    expect(find.textContaining('removido.'), findsOneWidget);
    await tester.pumpAndSettle();

    // voltou a oferecer baixar
    expect(find.byTooltip('Baixar'), findsOneWidget);
  });

  testWidgets('tap no card de outro autor: snackbar somente leitura', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Harpa de Outrem'));
    await tester.pump();
    expect(find.textContaining('somente leitura'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
