import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';
import 'package:louvorja_piano_mobile/presentation/custom/custom_collections_page.dart';

/// Tela de Coletâneas: denunciar e bloquear autor (App Store 1.2).
class _MemStorage implements FlutterSecureStorage {
  final Map<String, String> backing = {};
  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.namedArguments;
    if (i.memberName == #write) {
      final v = n[#value] as String?;
      if (v == null) {
        backing.remove(n[#key] as String);
      } else {
        backing[n[#key] as String] = v;
      }
      return Future<void>.value();
    }
    if (i.memberName == #read) {
      return Future<String?>.value(backing[n[#key] as String]);
    }
    if (i.memberName == #delete) {
      backing.remove(n[#key] as String);
      return Future<void>.value();
    }
    return null;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<String> calls = [];
  final List<Map<String, dynamic>> collections;
  _RecordingAdapter(this.collections);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    final path = options.uri.path;
    final body = path.endsWith('/block-author')
        ? '{"blocked":{"id_user":9,"displayName":"Maria"}}'
        : path.endsWith('/report')
        ? '{"ok":true}'
        : '{"data": ${jsonEncode(collections)}}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Future<CustomAuthController> _loggedIn() async {
  final store = CustomSessionStore(storage: _MemStorage());
  await store.save(
    const CustomSession(
      token: 'tok',
      user: CustomUser(idUser: 1, email: 'a@b.c', displayName: 'Ana'),
    ),
  );
  return CustomAuthController(
    CustomAuthApiImpl(
      // me(): erro transitório mantém a sessão salva.
      fetch: (method, url, {body, bearerToken}) async =>
          throw DioException(requestOptions: RequestOptions(path: url)),
      apiBaseUrl: 'https://api.test',
      sessionStore: store,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const other = {
    'id_collection': 42,
    'name': 'Harpa de Outrem',
    'author_name': 'Maria',
    'musics_count': 7,
    'is_owner': 0,
  };
  const mine = {
    'id_collection': 43,
    'name': 'Minha',
    'author_name': 'Ana',
    'musics_count': 1,
    'is_owner': 1,
  };

  Future<_RecordingAdapter> pumpPage(WidgetTester tester) async {
    final adapter = _RecordingAdapter([other, mine]);
    final dio = Dio()..httpClientAdapter = adapter;
    final auth = await _loggedIn();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomCollectionsPage(dio: dio, authController: auth),
      ),
    );
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('menu de moderação só nas coletâneas de outros autores', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('collection-moderation-42')), findsOneWidget);
    expect(find.byKey(const Key('collection-moderation-43')), findsNothing);
  });

  testWidgets('bloquear autor chama a API e recarrega a lista', (tester) async {
    final adapter = await pumpPage(tester);
    final loadsBefore = adapter.calls
        .where((c) => c == 'GET /v1/custom/collections')
        .length;

    await tester.tap(find.byKey(const Key('collection-moderation-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear autor'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquear Maria?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
    await tester.pumpAndSettle();

    expect(
      adapter.calls,
      contains('POST /v1/custom/collections/42/block-author'),
    );
    expect(find.text('Maria bloqueado.'), findsOneWidget);
    expect(
      adapter.calls.where((c) => c == 'GET /v1/custom/collections').length,
      greaterThan(loadsBefore),
    );
  });

  testWidgets('denunciar envia o motivo escolhido', (tester) async {
    final adapter = await pumpPage(tester);

    await tester.tap(find.byKey(const Key('collection-moderation-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conteúdo ofensivo ou inadequado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Denunciar'));
    await tester.pumpAndSettle();

    expect(adapter.calls, contains('POST /v1/custom/collections/42/report'));
    expect(find.textContaining('Denúncia enviada'), findsOneWidget);
  });

  testWidgets('menu da conta tem usuários bloqueados e excluir conta', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('custom-account-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Usuários bloqueados'), findsOneWidget);
    expect(find.text('Excluir conta'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });
}
