library;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'palco_controller.dart';
import 'palco_sender.dart';
import '../dlna/stage_settings_repository.dart';
import '../dlna/stage_slide_painter.dart' show StageSettings;

/// Um slot de palco = 1 TV conectada via PalcoController.
///
/// Cada slot tem portas WS/HTTP próprias (incrementais), settings
/// independentes e estado de conexão próprio.
class PalcoSlot extends ChangeNotifier {
  PalcoSlot({required this.id, required this.label, required int slotIndex})
    : _slotIndex = slotIndex {
    controller = PalcoController(
      sender: PalcoSender(
        httpPortFixed: _baseHttpPort,
        wsPortFixed: _baseWsPort,
        slotId: id,
        slotLabel: label,
      ),
    );
    _settingsRepo = StageSettingsRepository(scope: 'global');
    // Multi-palco: estado de conexão do controller (TV conectou/saiu)
    // precisa fluir slot -> orchestrator -> UI. Sem isso o gerenciador
    // só atualizava fechando e abrindo (bug 2026-08-21).
    controller.addListener(notifyListeners);
  }

  final String id;
  String label;
  final int _slotIndex;
  late final PalcoController controller;
  late final StageSettingsRepository _settingsRepo;

  /// Portas HTTP/WS calculadas a partir do índice do slot.
  /// Slot 0: 7080/7081, Slot 1: 7082/7083, etc.
  int get _baseHttpPort => 7080 + (_slotIndex * 2);
  int get _baseWsPort => 7081 + (_slotIndex * 2);
  int get slotIndex => _slotIndex;
  int get httpPort => _baseHttpPort;
  int get wsPort => _baseWsPort;

  bool get isConnected => controller.isConnected;
  String? get receiverIp => controller.receiverIp;

  StageSettings settings = const StageSettings();

  Future<bool> connect(PalcoTarget tv) async {
    settings = await _settingsRepo.load();
    final ok = await controller.connect(tv);
    if (ok) notifyListeners();
    return ok;
  }

  Future<void> disconnect() async {
    await controller.disconnect();
    notifyListeners();
  }

  Future<void> updateSettings(StageSettings s) async {
    settings = s;
    await _settingsRepo.save(s);
    notifyListeners();
  }

  @override
  String toString() => 'PalcoSlot($id, $label, ports $httpPort/$wsPort)';
}
