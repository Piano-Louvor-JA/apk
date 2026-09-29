import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collections_page.dart';

/// Storage falso (sem plugin nativo) pro controller de auth do teste.
class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> backing = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    if (invocation.memberName == #write) {
      final key = named[#key] as String;
      final value = named[#value] as String?;
      if (value == null) {
        backing.remove(key);
      } else {
        backing[key] = value;
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #read) {
      return Future<String?>.value(backing[named[#key] as String]);
    }
    if (invocation.memberName == #delete) {
      backing.remove(named[#key] as String);
      return Future<void>.value();
    }
    return null;
  }
}

/// Controller de auth apontando pra API que falha (não interessa pro teste —
/// só precisa não pendurar o restore()).
CustomAuthController _fakeAuth() => CustomAuthController(
  CustomAuthApiImpl(
    fetch: (method, url, {body, bearerToken}) async =>
        throw DioException(requestOptions: RequestOptions(path: url)),
    apiBaseUrl: 'https://api.test',
    sessionStore: CustomSessionStore(storage: _FakeStorage()),
  ),
);

/// Adapter que lança DioException fixa — simula falha de rede (RF-01/RF-02).
class _FailingAdapter implements HttpClientAdapter {
  final DioException error;
  _FailingAdapter(this.error);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw error;
  }
}

/// Adapter que devolve JSON fixo — caminho feliz.
class _OkAdapter implements HttpClientAdapter {
  final Map<String, dynamic> payload;
  _OkAdapter(this.payload);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"data": []}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

// A página deriva a base da URL de database (menos /json_db). Pinamos a env
// para que o Dio injetado receba a URL certa.
void _pinApiConfig() {
  // ApiConfig usa fromEnvironment — não é mutável em teste. O teste do caminho
  // feliz usa o dio injetado: o adapter captura a RequestOptions com a URL
  // real derivada da config de teste, então não precisamos fixar a URL —
  // basta que o adapter responda a qualquer URL.
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _pinApiConfig();
  });

  group('CustomCollectionsPage RF-01: timeout no Dio padrão', () {
    test('buildDefaultDio tem connectTimeout 8s e receiveTimeout 15s', () {
      final dio = CustomCollectionsPage.buildDefaultDio();
      expect(dio.options.connectTimeout, const Duration(seconds: 8));
      expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    });
  });

  group('CustomCollectionsPage RF-02: erro com tipo da falha na UI', () {
    testWidgets('DioException(connectionTimeout) aparece na tela', (
      tester,
    ) async {
      final dio =
          Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 15),
              ),
            )
            ..httpClientAdapter = _FailingAdapter(
              DioException(
                requestOptions: RequestOptions(path: '/v1/custom/collections'),
                type: DioExceptionType.connectionTimeout,
              ),
            );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionsPage(dio: dio, authController: _fakeAuth()),
        ),
      );

      // initState -> _load async: primeira pump roda frame, depois microtasks
      await tester.pumpAndSettle();

      expect(find.textContaining('connectionTimeout'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('caminho feliz lista coletâneas sem erro', (tester) async {
      final dio = Dio()..httpClientAdapter = _OkAdapter({'data': []});

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionsPage(dio: dio, authController: _fakeAuth()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sem conex'), findsNothing);
      expect(find.textContaining('Nenhuma coletânea'), findsOneWidget);
    });
  });

  group('CustomCollectionsPage: criação local SEM auth', () {
    testWidgets('FAB "Nova coletânea" visível sem autenticação', (
      tester,
    ) async {
      final dio = Dio()..httpClientAdapter = _OkAdapter({'data': []});

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionsPage(dio: dio, authController: _fakeAuth()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nova coletânea'), findsOneWidget);
    });

    testWidgets('coletânea local (id<0) aparece na lista mesclada', (
      tester,
    ) async {
      final dio = Dio()..httpClientAdapter = _OkAdapter({'data': []});

      await tester.pumpWidget(
        MaterialApp(
          home: CustomCollectionsPage(dio: dio, authController: _fakeAuth()),
        ),
      );
      await tester.pumpAndSettle();

      // cria coletânea local via FAB
      await tester.tap(find.text('Nova coletânea'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome').first,
        'Coletânea Local Teste',
      );
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      // aparece na lista (isOwner local) — não precisa de conta
      expect(find.text('Coletânea Local Teste'), findsOneWidget);
      expect(find.text('por Este dispositivo'), findsOneWidget);
    });
  });
}
