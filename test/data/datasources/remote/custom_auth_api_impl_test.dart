import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';

/// Storage falso em memória (sem plugin nativo em teste).
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> backing = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #write) {
      final named = invocation.namedArguments;
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
      final named = invocation.namedArguments;
      final key = named[#key] as String;
      return Future<String?>.value(backing[key]);
    }
    if (invocation.memberName == #delete) {
      final named = invocation.namedArguments;
      final key = named[#key] as String;
      backing.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

/// Responde conforme o script: 'network' = falha de conexão,
/// int = status HTTP, senão 200 com o corpo JSON informado.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<({String method, String url, String? bearer})> calls = [];
  final Object? Function(String method, String url, Map<String, dynamic>? body)
  _responder;

  _ScriptedAdapter(this._responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : null;
    calls.add((
      method: options.method,
      url: options.uri.toString(),
      bearer: options.headers['Authorization']?.toString().replaceFirst(
        'Bearer ',
        '',
      ),
    ));
    final result = _responder(options.method, options.uri.toString(), body);
    if (result == 'network') {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (result is int) {
      return ResponseBody.fromString('{"error":"x"}', result);
    }
    return ResponseBody.fromString(
      result as String,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _okAuthResponse =
    '{"token":"tok123","user":{"id_user":7,"email":"a@b.c","displayName":"Rafael"}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorage storage;
  late CustomSessionStore store;
  late CustomAuthApiImpl auth;
  late _ScriptedAdapter adapter;

  setUp(() {
    storage = _FakeSecureStorage();
    store = CustomSessionStore(storage: storage);
    adapter = _ScriptedAdapter((method, url, body) => _okAuthResponse);
    auth = CustomAuthApiImpl(
      fetch: (method, url, {body, bearerToken}) async {
        // ponte: usa o adapter p/ registrar chamadas e devolver JSON decodificado
        final req = RequestOptions(path: url, method: method, data: body)
          ..headers['Authorization'] = bearerToken == null
              ? null
              : 'Bearer $bearerToken';
        final rb = await adapter.fetch(req, null, null);
        final chunks = <int>[];
        await for (final c in rb.stream) {
          chunks.addAll(c);
        }
        final text = utf8.decode(chunks);
        return text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      },
      apiBaseUrl: 'https://api.test',
      sessionStore: store,
    );
  });

  group('login', () {
    test('POST /auth/login + sessão salva', () async {
      final session = await auth.login(email: 'a@b.c', password: 'secret1');

      expect(session.token, 'tok123');
      expect(session.user.displayName, 'Rafael');
      expect(adapter.calls.single.url, contains('/v1/custom/auth/login'));
      // persistiu
      final stored = await store.read();
      expect(stored?.token, 'tok123');
    });

    test('401 → CustomAuthException invalidCredentials', () async {
      auth = CustomAuthApiImpl(
        fetch: (method, url, {body, bearerToken}) => Future.error(
          DioException(
            requestOptions: RequestOptions(path: url),
            response: Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 401,
              data: {'error': 'credenciais'},
            ),
          ),
        ),
        apiBaseUrl: 'https://api.test',
        sessionStore: store,
      );

      await expectLater(
        auth.login(email: 'a@b.c', password: 'wrong'),
        throwsA(
          predicate(
            (e) =>
                e is CustomAuthException &&
                e.code == 'errors.invalidCredentials',
          ),
        ),
      );
    });

    test('409 → emailInUse no registro', () async {
      auth = CustomAuthApiImpl(
        fetch: (method, url, {body, bearerToken}) => Future.error(
          DioException(
            requestOptions: RequestOptions(path: url),
            response: Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 409,
              data: {'error': 'já cadastrado'},
            ),
          ),
        ),
        apiBaseUrl: 'https://api.test',
        sessionStore: store,
      );

      await expectLater(
        auth.register(email: 'a@b.c', password: 'secret1', displayName: 'R'),
        throwsA(
          predicate(
            (e) => e is CustomAuthException && e.code == 'errors.emailInUse',
          ),
        ),
      );
    });
  });

  group('logout', () {
    test('chama API com Bearer e limpa sessão', () async {
      await auth.login(email: 'a@b.c', password: 'secret1');
      await auth.logout();

      expect(await store.read(), isNull);
    });

    test('sem sessão → só limpa (não lança)', () async {
      await auth.logout();
      expect(await store.read(), isNull);
    });
  });

  group('me', () {
    test('sem sessão → null sem chamar API', () async {
      expect(await auth.me(), isNull);
    });

    test('401 → limpa sessão e retorna null', () async {
      await store.save(
        const CustomSession(
          token: 'expired',
          user: CustomUser(idUser: 1, email: 'a@b.c', displayName: 'A'),
        ),
      );
      auth = CustomAuthApiImpl(
        fetch: (method, url, {body, bearerToken}) => Future.error(
          DioException(
            requestOptions: RequestOptions(path: url),
            response: Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 401,
            ),
          ),
        ),
        apiBaseUrl: 'https://api.test',
        sessionStore: store,
      );

      expect(await auth.me(), isNull);
      expect(await store.read(), isNull);
    });
  });

  group('CustomSessionStore', () {
    test('read de dado corrompido → null + limpa', () async {
      await storage.write(key: 'louvorja.custom.session', value: 'não-json');
      expect(await store.read(), isNull);
      expect(storage.backing.containsKey('louvorja.custom.session'), isFalse);
    });
  });
}
