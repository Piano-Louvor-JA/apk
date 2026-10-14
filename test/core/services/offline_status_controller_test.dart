// SPEC 7 (apk#92) — modo offline: estado observável de rede p/ banner + retry.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart'
    show Connectivity, ConnectivityResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/connectivity_service.dart';

class _FakeConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _current;
  Completer<List<ConnectivityResult>>? pending;
  bool failCheck = false;

  _FakeConnectivity(List<ConnectivityResult> initial) : _current = initial;

  void change(List<ConnectivityResult> results) {
    _current = results;
    _changes.add(results);
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (failCheck) throw StateError('sem plugin');
    return pending == null ? _current : await pending!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('falha inicial permite tentar novamente', () async {
    final fake = _FakeConnectivity([ConnectivityResult.none])..failCheck = true;
    final controller = OfflineStatusController(
      service: ConnectivityService(connectivity: fake),
    );
    try {
      await controller.start();
    } catch (_) {}
    fake.failCheck = false;
    await controller.start();
    expect(controller.isOffline, isTrue);
    await controller.dispose();
  });

  test(
    'mudança durante consulta inicial prevalece sobre resultado antigo',
    () async {
      final fake = _FakeConnectivity([ConnectivityResult.wifi])
        ..pending = Completer<List<ConnectivityResult>>();
      final controller = OfflineStatusController(
        service: ConnectivityService(connectivity: fake),
      );
      final starting = controller.start();
      fake.change([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      fake.pending!.complete([ConnectivityResult.wifi]);
      await starting;
      expect(controller.isOffline, isTrue);
      await controller.dispose();
    },
  );

  test(
    'dispose durante consulta inicial não emite em stream fechado',
    () async {
      final fake = _FakeConnectivity([ConnectivityResult.none])
        ..pending = Completer<List<ConnectivityResult>>();
      final controller = OfflineStatusController(
        service: ConnectivityService(connectivity: fake),
      );
      final starting = controller.start();
      await controller.dispose();
      fake.pending!.complete([ConnectivityResult.none]);
      await expectLater(starting, completes);
    },
  );

  test('OfflineStatusController inicia refletindo o estado atual', () async {
    final fake = _FakeConnectivity([ConnectivityResult.none]);
    final controller = OfflineStatusController(
      service: ConnectivityService(connectivity: fake),
    );
    await controller.start();
    expect(controller.isOffline, isTrue);
    await controller.dispose();
  });

  test('OfflineStatusController emite offline true ao perder rede', () async {
    final fake = _FakeConnectivity([ConnectivityResult.wifi]);
    final controller = OfflineStatusController(
      service: ConnectivityService(connectivity: fake),
    );
    await controller.start();
    expect(controller.isOffline, isFalse);

    final offlineValues = <bool>[];
    final sub = controller.onOfflineChanged.listen(offlineValues.add);

    fake.change([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOffline, isTrue);
    expect(offlineValues, contains(true));

    await sub.cancel();
    await controller.dispose();
  });

  test('OfflineStatusController emite online ao voltar a rede', () async {
    final fake = _FakeConnectivity([ConnectivityResult.none]);
    final controller = OfflineStatusController(
      service: ConnectivityService(connectivity: fake),
    );
    await controller.start();
    expect(controller.isOffline, isTrue);

    fake.change([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOffline, isFalse);
    await controller.dispose();
  });

  test('start() duas vezes não duplica assinatura', () async {
    final fake = _FakeConnectivity([ConnectivityResult.wifi]);
    final controller = OfflineStatusController(
      service: ConnectivityService(connectivity: fake),
    );
    await controller.start();
    await controller.start();
    fake.change([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOffline, isTrue);
    await controller.dispose();
  });
}
