import 'dart:async';

import 'package:louvorja_piano_mobile/core/services/palco/palco_sender.dart';

/// Configuração global da suíte (carregada pelo `flutter test` antes de cada
/// arquivo em test/).
///
/// `flutter test` roda arquivos em processos paralelos. Testes que ligam o
/// Palco pelo StageSession/PalcoOrchestrator sobem o sender nas portas fixas
/// dos slots (7080/7081, 7082/7083...) e colidiam entre si
/// (`Address already in use`). Aqui todo sender faz bind em porta efêmera;
/// os testes conectam na porta real (`controller.wsPort` /
/// `sender.effectiveWsPort`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PalcoSender.bindEphemeralPortsForTesting = true;
  await testMain();
}
