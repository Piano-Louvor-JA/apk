library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/telemetry_api_client.dart';
import '../../constants/app_version.dart';
import '../../platform_header.dart';
import '../home_location_preferences.dart';

/// Telemetria de dispositivos online — sinal de "online" do APK.
///
/// Fonte: pianolouvorja/app/src/modules/telemetry (desktop). Mesmo corpo do
/// POST /v1/telemetry/heartbeat. Sempre ligado (recurso padrao, sem opcao de
/// desativar). Sem dados pessoais: id anonimo gerado no aparelho, SO,
/// versao e o distrito/igreja digitados.

/// UUID v4 anonimo desta instalacao (mesma chave do desktop). Local: nao
/// sincroniza com a conta.
abstract final class TelemetryInstallId {
  static const storageKey = 'telemetry.installId';
  static final _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    if (stored != null && _uuidV4.hasMatch(stored)) return stored;
    final id = _newUuidV4();
    await prefs.setString(storageKey, id);
    return id;
  }

  static String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class DeviceOs {
  final String name;
  final String release;
  final String arch;

  const DeviceOs({required this.name, this.release = '', this.arch = ''});

  Map<String, String> toJson() => {
    'name': name,
    'release': release,
    'arch': arch,
  };
}

/// SO legivel: "Android" + "14 · samsung SM-A546E" / "iOS" + "18.1 · iPhone16,1".
// coverage:ignore-start
Future<DeviceOs?> readDeviceOs() async {
  final device = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final info = await device.androidInfo;
    return DeviceOs(
      name: 'Android',
      release: '${info.version.release} · ${info.manufacturer} ${info.model}',
    );
  }
  if (Platform.isIOS) {
    final info = await device.iosInfo;
    return DeviceOs(
      name: 'iOS',
      release: '${info.systemVersion} · ${info.utsname.machine}',
    );
  }
  return null;
}
// coverage:ignore-end

/// Monta o corpo do heartbeat. Dependencias injetaveis para teste.
class HeartbeatBodyBuilder {
  final String Function() platform;
  final Future<String> Function() version;
  final Future<DeviceOs?> Function() os;
  final String Function() locale;
  final String Function() timezone;

  HeartbeatBodyBuilder({
    String Function()? platform,
    Future<String> Function()? version,
    Future<DeviceOs?> Function()? os,
    String Function()? locale,
    String Function()? timezone,
  }) : platform = platform ?? clientPlatform,
       version = version ?? (() => AppVersion.version),
       os = os ?? readDeviceOs,
       locale =
           locale ??
           (() => WidgetsBinding.instance.platformDispatcher.locale
               .toLanguageTag()),
       timezone = timezone ?? (() => DateTime.now().timeZoneName);

  Future<Map<String, Object?>> build() async {
    final location = await HomeLocationPreferences.resolveReported();
    DeviceOs? deviceOs;
    try {
      deviceOs = await os();
    } catch (_) {
      deviceOs = null;
    }
    final appVersion = await version();
    return {
      'install_id': await TelemetryInstallId.getOrCreate(),
      'platform': platform(),
      'app_version': appVersion.isEmpty ? null : appVersion,
      'os': deviceOs?.toJson(),
      'locale': locale(),
      'timezone': timezone(),
      'district': location.district.isEmpty ? null : location.district,
      'church': location.church.isEmpty ? null : location.church,
    };
  }
}

/// Hosts da API Piano (STG/prod/local); a API PHP legada nao tem o endpoint.
bool isPianoApiHost(String host) {
  final h = host.toLowerCase();
  return h == 'localhost' ||
      h == '127.0.0.1' ||
      h == '10.0.2.2' ||
      h == 'pianolouvorja.com.br' ||
      h.endsWith('.pianolouvorja.com.br');
}

/// Bases da cascata (`<origem>/json_db`) → URLs do heartbeat, sem repetir.
List<String> heartbeatUrlsFrom(List<String> bases) {
  final urls = <String>[];
  for (final base in bases) {
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) continue;
    if (!isPianoApiHost(uri.host)) continue;
    final url = '${uri.origin}/v1/telemetry/heartbeat';
    if (!urls.contains(url)) urls.add(url);
  }
  return urls;
}

/// Loop do sinal: ao iniciar e a cada 5 min, so com o app em primeiro plano
/// (em segundo plano o sistema corta timers e gastaria bateria). Ao voltar
/// para a frente envia na hora. Salvar distrito/igreja envia apos 3 s.
class HeartbeatLoop with WidgetsBindingObserver {
  static const interval = Duration(minutes: 5);
  static const locationDebounce = Duration(seconds: 3);

  final TelemetryApiClient api;
  final HeartbeatBodyBuilder builder;

  HeartbeatLoop({required this.api, required this.builder});

  Timer? _timer;
  Timer? _debounce;
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    HomeLocationPreferences.savedChanges.addListener(_onLocationSaved);
    _startTimer();
  }

  void stop() {
    _running = false;
    _stopTimer();
    _debounce?.cancel();
    _debounce = null;
    WidgetsBinding.instance.removeObserver(this);
    HomeLocationPreferences.savedChanges.removeListener(_onLocationSaved);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _send());
    _send();
  }

  void _stopTimer() {
    _debounce?.cancel();
    _debounce = null;
    _timer?.cancel();
    _timer = null;
  }

  void _onLocationSaved() {
    if (!_running || _timer == null) return;
    _debounce?.cancel();
    _debounce = Timer(locationDebounce, () {
      _debounce = null;
      _send();
    });
  }

  void _send() {
    unawaited(() async {
      try {
        if (!_running || _timer == null) return;
        final body = await builder.build();
        // O app pode ter sido pausado enquanto as preferencias eram lidas.
        if (!_running || _timer == null) return;
        await api.sendHeartbeat(body);
      } catch (_) {
        // Silencioso: tenta no proximo ciclo.
      }
    }());
  }
}
