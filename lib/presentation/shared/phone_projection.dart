import 'package:louvorja_piano_mobile/core/services/dlna/slide_http_server.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart'
    show PalcoTarget;
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/tools/monitor_share_link.dart';

/// Preparo da setinha de projetar, igual em Hinos e na Liturgia local: liga
/// o palco do celular (conexão Principal), reconecta os monitores do
/// computador compartilhados e os mostra. Assim a projeção chega a todos os
/// destinos marcados em Telas: monitores compartilhados, conexões remotas e
/// TVs do Palco.
abstract final class PhoneProjection {
  /// false = não deu para ligar o palco (sem rede Wi-Fi).
  static Future<bool> begin() async {
    final stage = StageSession.instance;
    if (!stage.isPalcoMode && !await _turnOnPhoneStage()) return false;
    // Monitores do computador: reconecta se estava salvo e caiu.
    final principal = PalcoOrchestrator.instance.slot('principal');
    final ip = SlideHttpServer.localIp;
    if (principal != null && ip != null) {
      await MonitorShareSession.instance.ensureConnected(
        phoneIp: ip,
        wsPort: principal.wsPort,
      );
    }
    await MonitorShareSession.instance.setProjecting(true);
    return true;
  }

  /// Sem projeção: esconde as telas do computador (se a opção pedir).
  static Future<void> end() =>
      MonitorShareSession.instance.setProjecting(false);

  /// Liga o palco do celular (conexão Principal), igual à Transmissão.
  static Future<bool> _turnOnPhoneStage() async {
    final orch = PalcoOrchestrator.instance;
    await orch.loadStoredConfig();
    if (orch.slot('principal') == null) {
      orch.addSlot(id: 'principal', label: 'Principal');
    }
    final principal = orch.slot('principal')!;
    await SlideHttpServer.resolveLocalIp();
    final ip = SlideHttpServer.localIp;
    if (ip == null) return false;
    return StageSession.instance.turnOnPalco(
      PalcoTarget(name: principal.label, ip: ip, wsPort: principal.wsPort),
    );
  }
}
