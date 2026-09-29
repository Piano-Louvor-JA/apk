library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Resultado do pedido de instalação via PackageInstaller nativo.
enum ApkInstallOutcome {
  /// Sessão commitada; o sistema cuida do resto (diálogo ou install).
  delivered,

  /// O app não tem permissão de fonte desconhecida — as Configurações
  /// do sistema foram abertas na tela correta. Usuário concede e retenta.
  needsPermission,

  /// Channel falhou/ausente — chamador usa o fallback legado (OpenFilex).
  failed,
}

/// Instala um APK baixado.
///
/// Android: PackageInstaller.Session via platform channel
/// (`app.louvorja/updater`) — bytes vão direto pra sessão do SISTEMA,
/// sem FileProvider/URI content://.
///
/// 2026-08-16 (bug 0.1.16→0.1.17 não instalava): o receiver do resultado
/// não estava no manifest e ignorava STATUS_PENDING_USER_ACTION — o
/// diálogo de confirmação do sistema nunca era iniciado. O nativo agora
/// devolve 'delivered' | 'needs_permission'; qualquer outra coisa vira
/// [ApkInstallOutcome.failed] (fallback OpenFilex).
class ApkInstaller {
  static const _channel = MethodChannel('app.louvorja/updater');

  static Future<ApkInstallOutcome> install(String apkPath) async {
    if (kIsWeb) return ApkInstallOutcome.failed;
    try {
      final r = await _channel.invokeMethod<dynamic>('installApk', {
        'path': apkPath,
      });
      return switch (r) {
        'needs_permission' => ApkInstallOutcome.needsPermission,
        'delivered' => ApkInstallOutcome.delivered,
        _ => ApkInstallOutcome.delivered,
      };
    } on PlatformException {
      return ApkInstallOutcome.failed;
    } on MissingPluginException {
      return ApkInstallOutcome.failed;
    }
  }
}
