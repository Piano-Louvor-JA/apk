import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/data/datasources/remote/custom_auth_api_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';

/// Estado do auth custom para a UI.
enum CustomAuthStatus { unknown, authenticated, unauthenticated }

/// Controller de sessão custom (ChangeNotifier — 1 usuário, sem BLoC).
///
/// - restore() na inicialização: valida sessão salva (me()).
/// - login/register/logout atualizam o estado e notificam.
class CustomAuthController extends ChangeNotifier {
  final CustomAuthApiImpl api;

  CustomAuthStatus status = CustomAuthStatus.unknown;
  CustomSession? session;
  String? errorCode;

  CustomAuthController(this.api);

  bool get isAuthenticated => status == CustomAuthStatus.authenticated;

  /// Valida sessão persistida ao abrir o app.
  Future<void> restore() async {
    final s = await api.me();
    session = s;
    status = s == null
        ? CustomAuthStatus.unauthenticated
        : CustomAuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    return _run(() => api.login(email: email, password: password));
  }

  Future<bool> register(
    String email,
    String password,
    String displayName,
  ) async {
    return _run(
      () => api.register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<bool> _run(Future<CustomSession> Function() action) async {
    errorCode = null;
    try {
      session = await action();
      status = CustomAuthStatus.authenticated;
      notifyListeners();
      return true;
    } on CustomAuthException catch (e) {
      errorCode = e.code;
      status = CustomAuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await api.logout();
    session = null;
    status = CustomAuthStatus.unauthenticated;
    notifyListeners();
  }
}
