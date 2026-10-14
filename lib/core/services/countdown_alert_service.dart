library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Alerta local de término do countdown.
///
/// Em Android/iOS exibe notificação com vibração quando o app ainda está vivo.
/// No Web não há plugin equivalente com a mesma garantia; o timer continua
/// visual e a página pode complementar com feedback de UI.
class CountdownAlertService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  CountdownAlertService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> notifyFinished() async {
    if (kIsWeb) return;
    await _ensureInitialized();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'countdown_alerts',
        'Alertas de cronômetro',
        channelDescription: 'Alertas emitidos quando um countdown termina.',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      ),
    );
    await _plugin.show(
      id: 7001,
      title: 'Countdown concluído',
      body: 'O tempo programado chegou ao fim.',
      notificationDetails: details,
    );
  }
}
