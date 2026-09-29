library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de conectividade para o modo online-first do app.
///
/// Conectividade de rede não garante acesso à internet. Na Fase 2, o
/// repositório confirma disponibilidade ao executar chamadas à API.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  Stream<bool> get onConnectionChanged =>
      _connectivity.onConnectivityChanged.map(_isConnected).distinct();

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// true quando conectado via Wi-Fi (download sob demanda só em Wi-Fi).
  Future<bool> get isWifi async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
}

/// Estado observável simples para widgets.
class ConnectivityController {
  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;
  final StreamController<bool> _state = StreamController<bool>.broadcast();

  ConnectivityController({ConnectivityService? service})
    : _service = service ?? ConnectivityService();

  Stream<bool> get state => _state.stream;

  Future<void> start() async {
    _state.add(await _service.isConnected);
    _subscription = _service.onConnectionChanged.listen(_state.add);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _state.close();
  }
}
