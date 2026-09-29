import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';
import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';

const _ok =
    '{"token":"tok","user":{"id_user":1,"email":"a@b.c","displayName":"R"}}';

CustomAuthApiImpl _apiWith(
  Future<dynamic> Function(
    String,
    String, {
    Map<String, dynamic>? body,
    String? bearerToken,
  })
  fetch,
  CustomSessionStore store,
) {
  return CustomAuthApiImpl(
    fetch: fetch,
    apiBaseUrl: 'https://api.test',
    sessionStore: store,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CustomSessionStore store;

  setUp(() {
    store = CustomSessionStore(storage: _MemStorage());
  });

  test('estado inicial unknown', () {
    final c = CustomAuthController(
      _apiWith((m, u, {body, bearerToken}) async => _ok, store),
    );
    expect(c.status, CustomAuthStatus.unknown);
  });

  test('login sucesso → authenticated + notifica', () async {
    final c = CustomAuthController(
      _apiWith((m, u, {body, bearerToken}) async => _ok, store),
    );
    var notified = 0;
    c.addListener(() => notified++);

    final ok = await c.login('a@b.c', 'secret1');

    expect(ok, isTrue);
    expect(c.isAuthenticated, isTrue);
    expect(c.session?.token, 'tok');
    expect(notified, greaterThanOrEqualTo(1));
  });

  test('login 401 → unauthenticated + errorCode', () async {
    final c = CustomAuthController(
      _apiWith((m, u, {body, bearerToken}) async {
        throw const CustomAuthException('errors.invalidCredentials', 'x');
      }, store),
    );

    final ok = await c.login('a@b.c', 'wrong');

    expect(ok, isFalse);
    expect(c.isAuthenticated, isFalse);
    expect(c.errorCode, 'errors.invalidCredentials');
  });

  test('logout → unauthenticated + sessão limpa', () async {
    final c = CustomAuthController(
      _apiWith((m, u, {body, bearerToken}) async => _ok, store),
    );
    await c.login('a@b.c', 'secret1');

    await c.logout();

    expect(c.isAuthenticated, isFalse);
    expect(await store.read(), isNull);
  });

  test('restore com sessão válida → authenticated', () async {
    await store.save(
      const CustomSession(
        token: 't',
        user: CustomUser(idUser: 1, email: 'a@b.c', displayName: 'R'),
      ),
    );
    final c = CustomAuthController(
      _apiWith((m, u, {body, bearerToken}) async {
        // me() com Bearer válido
        expect(bearerToken, 't');
        return _ok;
      }, store),
    );

    await c.restore();

    expect(c.isAuthenticated, isTrue);
  });

  test('restore sem sessão → unauthenticated sem chamar API', () async {
    var called = false;
    final c = CustomAuthController(
      _apiWith((m, u, {body, bearerToken}) async {
        called = true;
        return _ok;
      }, store),
    );

    await c.restore();

    expect(called, isFalse);
    expect(c.status, CustomAuthStatus.unauthenticated);
  });
}

/// Storage mínimo em memória pro teste do controller.
class _MemStorage implements FlutterSecureStorage {
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
