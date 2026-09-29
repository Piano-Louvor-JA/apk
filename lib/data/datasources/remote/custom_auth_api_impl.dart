import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:louvorja_piano_mobile/data/datasources/local/custom_session_store.dart';
import 'package:louvorja_piano_mobile/domain/entities/custom_auth.dart';

/// Cliente de auth custom (API /v1/custom/auth/*).
///
/// Mesmo padrão do CustomCatalogApiImpl: função de rede injetável pra
/// testar sem mockar Dio. Sempre envia Bearer quando há sessão.
class CustomAuthApiImpl {
  final CustomFetch _fetch;
  final String apiBaseUrl;
  final CustomSessionStore sessionStore;

  CustomAuthApiImpl({
    required CustomFetch fetch,
    required this.apiBaseUrl,
    required this.sessionStore,
  }) : _fetch = fetch;

  String _authUrl(String path) => '$apiBaseUrl/v1/custom/auth$path';

  Future<CustomSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _authenticate('/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
  }

  Future<CustomSession> login({
    required String email,
    required String password,
  }) async {
    return _authenticate('/login', {'email': email, 'password': password});
  }

  Future<CustomSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _fetch('POST', _authUrl(path), body: body);
      final map = _decode(res);
      final session = CustomSession(
        token: map['token'] as String,
        user: CustomUser.fromJson(map['user'] as Map<String, dynamic>),
      );
      await sessionStore.save(session);
      return session;
    } on CustomAuthException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'errors.connection');
    } catch (e) {
      throw CustomAuthException('errors.connection', 'Falha de rede: $e');
    }
  }

  /// Valida o token atual na API. 401 → limpa sessão.
  Future<CustomSession?> me() async {
    final session = await sessionStore.read();
    if (session == null) return null;
    try {
      final res = await _fetch(
        'POST',
        _authUrl('/me'),
        bearerToken: session.token,
      );
      final map = _decode(res);
      final user = CustomUser.fromJson(
        (map['user'] as Map<String, dynamic>? ?? map),
      );
      final fresh = CustomSession(token: session.token, user: user);
      await sessionStore.save(fresh);
      return fresh;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await sessionStore.clear();
        return null;
      }
      // Erro transitório: mantém a sessão local (offline-friendly).
      return session;
    } catch (_) {
      return session;
    }
  }

  Future<void> logout() async {
    final session = await sessionStore.read();
    try {
      if (session != null) {
        await _fetch('POST', _authUrl('/logout'), bearerToken: session.token);
      }
    } catch (_) {
      // logout é best-effort — limpa local de qualquer forma
    } finally {
      await sessionStore.clear();
    }
  }

  CustomAuthException _mapDio(DioException e, {required String fallback}) {
    final status = e.response?.statusCode;
    if (status == 409) {
      return const CustomAuthException(
        'errors.emailInUse',
        'E-mail já cadastrado',
      );
    }
    if (status == 401 || status == 422) {
      final msg = e.response?.data is Map
          ? (e.response?.data as Map)['error'] as String?
          : null;
      return CustomAuthException(
        'errors.invalidCredentials',
        msg ?? 'Credenciais inválidas',
      );
    }
    return CustomAuthException(fallback, 'Erro: ${e.message ?? e}');
  }

  Map<String, dynamic> _decode(dynamic raw) {
    if (raw is Response) return _decode(raw.data);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const CustomAuthException(
      'errors.unexpected',
      'Resposta inesperada da API',
    );
  }
}

/// Assinatura de fetch injetável (mesma do CustomCatalogApiImpl).
typedef CustomFetch =
    Future<dynamic> Function(
      String method,
      String url, {
      Map<String, dynamic>? body,
      String? bearerToken,
    });
