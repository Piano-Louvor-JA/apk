library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/dlna/slide_http_server.dart';
import '../../core/services/palco/palco_orchestrator.dart';

/// Endereço do desktop para usar os monitores dele (paridade com
/// Configurações › Projeção & Telas › Compartilhar monitores do app).
class MonitorShareTarget {
  final String address; // ip:porta do desktop (48090…)
  final String token;

  const MonitorShareTarget(this.address, this.token);

  /// QR do desktop: louvorja://monitors?host=IP:PORTA&token=CODIGO
  static MonitorShareTarget? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'louvorja' || uri.host != 'monitors') {
      return null;
    }
    final host = uri.queryParameters['host'] ?? '';
    final token = (uri.queryParameters['token'] ?? '').toUpperCase();
    if (!RegExp(r'^[\w.\-]+:\d{1,5}$').hasMatch(host)) return null;
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(token)) return null;
    return MonitorShareTarget(host, token);
  }

  /// Digitado: "192.168.0.130" ou "192.168.0.130:48090" + código.
  static MonitorShareTarget? manual(String address, String token) {
    var a = address.trim();
    if (a.isEmpty) return null;
    if (!a.contains(':')) a = '$a:48090';
    final t = token.trim().toUpperCase();
    if (!RegExp(r'^[\w.\-]+:\d{1,5}$').hasMatch(a)) return null;
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(t)) return null;
    return MonitorShareTarget(a, t);
  }
}

/// Monitor que o computador compartilhou com o celular.
class SharedMonitor {
  final int id;
  final String label;
  final String mode; // 'mirror' | 'return'
  final bool active; // marcado (✓) = recebe a projeção

  const SharedMonitor(this.id, this.label, this.mode, this.active);

  static List<SharedMonitor> listFrom(dynamic displays) => [
    if (displays is List)
      for (final d in displays.whereType<Map>())
        if (d['id'] is num && (d['mode'] == 'mirror' || d['mode'] == 'return'))
          SharedMonitor(
            (d['id'] as num).toInt(),
            (d['label'] ?? 'Monitor').toString(),
            d['mode'] as String,
            d['active'] != false,
          ),
  ];
}

/// Conexão atual com o computador (app inteiro): a tela "Conectar
/// monitor" e o painel do botão de TV leem o mesmo estado.
class MonitorShareSession extends ChangeNotifier {
  MonitorShareSession._();
  static final instance = MonitorShareSession._();

  MonitorShareTarget? target;
  bool connected = false;
  List<SharedMonitor> monitors = const [];
  bool busy = false;

  /// "Retirar fundo preto de espera": sem projeção, as janelas do
  /// computador ficam escondidas (o monitor mostra o que já tinha).
  static const _hideIdleKey = 'monitor_share_hide_idle';
  bool hideIdle = true;
  bool _hideIdleLoaded = false;

  /// Seta de projetar do miniplayer ligada?
  bool projectingNow = false;

  /// Janelas visíveis agora: sempre, ou só projetando.
  bool get windowsVisible => !hideIdle || projectingNow;

  Future<void> loadHideIdle() async {
    if (_hideIdleLoaded) return;
    _hideIdleLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    hideIdle = prefs.getBool(_hideIdleKey) ?? true;
    notifyListeners();
  }

  Future<void> setHideIdle(bool value) async {
    hideIdle = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideIdleKey, value);
    await _pushVisibility();
  }

  /// A seta começou/parou de projetar.
  Future<void> setProjecting(bool value) async {
    projectingNow = value;
    await _pushVisibility();
  }

  Future<void> _pushVisibility() async {
    final t = target;
    if (t == null || !connected) return;
    await MonitorShareLink.visibility(t, windowsVisible);
  }

  void _set({MonitorShareTarget? t, bool? on, List<SharedMonitor>? list}) {
    if (t != null) target = t;
    if (on != null) connected = on;
    if (list != null) monitors = list;
    notifyListeners();
  }

  void markConnected(MonitorShareTarget t) {
    _set(t: t, on: true);
    refresh();
  }

  void markDisconnected() => _set(on: false, list: const []);

  /// Reconecta com o endereço atual do celular (palco Principal no ar).
  Future<bool> _reconnect() async {
    final principal = PalcoOrchestrator.instance.slot('principal');
    await SlideHttpServer.resolveLocalIp();
    final ip = SlideHttpServer.localIp;
    if (principal == null || ip == null || !principal.controller.isRunning) {
      return false;
    }
    connected = false;
    return ensureConnected(phoneIp: ip, wsPort: principal.wsPort);
  }

  /// Projetar com o computador salvo mas desconectado (reiniciou, caiu a
  /// rede): reconecta sozinho para os monitores marcados receberem.
  Future<bool> ensureConnected({
    required String phoneIp,
    required int wsPort,
  }) async {
    final t = target ?? await MonitorShareLink.saved();
    if (t == null) return false;
    target = t;
    if (connected) {
      await refresh(); // confirma com o computador
      if (connected) return true;
    }
    await loadHideIdle();
    final (n, _) = await MonitorShareLink.connect(
      t,
      phoneIp: phoneIp,
      wsPort: wsPort,
      visible: windowsVisible,
    );
    if (n > 0) {
      markConnected(t);
      return true;
    }
    return false;
  }

  /// Lê do computador os monitores compartilhados e quais estão marcados.
  Future<void> refresh() async {
    final t = target;
    if (t == null || !connected) return;
    final list = await MonitorShareLink.status(t);
    if (list == null) return;
    // Computador reiniciou ou desconectou este celular: volta ao "conectar".
    if (!MonitorShareLink.lastStatusConnected) {
      markDisconnected();
      return;
    }
    _set(list: list);
  }

  /// ✓ no celular: só os marcados recebem a projeção.
  Future<String?> toggle(int id, bool on) async {
    final t = target;
    if (t == null || busy) return null;
    final ids = {
      for (final m in monitors)
        if (m.id == id ? on : m.active) m.id,
    };
    busy = true;
    _set(
      list: [
        for (final m in monitors)
          SharedMonitor(m.id, m.label, m.mode, ids.contains(m.id)),
      ],
    );
    var (list, error) = await MonitorShareLink.select(t, ids.toList());
    if (error == 'not_connected' && await _reconnect()) {
      // Computador reiniciou: reconecta e reaplica a escolha.
      (list, error) = await MonitorShareLink.select(t, ids.toList());
    }
    busy = false;
    if (list != null) {
      _set(list: list);
    } else {
      notifyListeners();
      await refresh();
      if (error == 'not_connected') markDisconnected();
    }
    return error;
  }
}

/// Fala com electron/monitor-share.mjs do desktop.
class MonitorShareLink {
  static const _key = 'monitor_share_target';
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
      validateStatus: (_) => true,
    ),
  );

  static Future<MonitorShareTarget?> saved() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getStringList(_key);
    if (v == null || v.length != 2) return null;
    return MonitorShareTarget(v[0], v[1]);
  }

  static Future<void> _save(MonitorShareTarget t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [t.address, t.token]);
  }

  /// Pede ao desktop para abrir os monitores apontados para este celular.
  /// Devolve (monitores abertos, erro legível).
  static Future<(int, String?)> connect(
    MonitorShareTarget target, {
    required String phoneIp,
    required int wsPort,
    bool visible = true,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        'http://${target.address}/monitor-share/connect',
        data: {
          'token': target.token,
          'host': phoneIp,
          'port': wsPort,
          'device': 'Celular',
          'visible': visible,
        },
      );
      if (res.statusCode == 401) return (0, 'Código inválido ou trocado no computador.');
      if (res.statusCode != 200) return (0, 'O computador recusou (${res.statusCode}).');
      await _save(target);
      final data = res.data;
      final n = data is Map && data['monitors'] is num
          ? (data['monitors'] as num).toInt()
          : 0;
      if (n == 0) {
        return (0, 'Conectado, mas nenhum monitor foi escolhido no computador.');
      }
      return (n, null);
    } on DioException {
      return (
        0,
        'Não achei o computador em ${target.address}. Mesma rede? '
            'Compartilhamento ligado no app?',
      );
    }
  }

  /// Última resposta de status: o computador ainda tem este celular?
  static bool lastStatusConnected = false;

  static Future<List<SharedMonitor>?> status(MonitorShareTarget target) async {
    try {
      final res = await _dio.get<dynamic>(
        'http://${target.address}/monitor-share/status',
        queryParameters: {'token': target.token},
      );
      if (res.statusCode != 200 || res.data is! Map) return null;
      lastStatusConnected = (res.data as Map)['connected'] == true;
      return SharedMonitor.listFrom((res.data as Map)['displays']);
    } on DioException {
      return null;
    }
  }

  static Future<(List<SharedMonitor>?, String?)> select(
    MonitorShareTarget target,
    List<int> ids,
  ) async {
    try {
      final res = await _dio.post<dynamic>(
        'http://${target.address}/monitor-share/select',
        data: {'token': target.token, 'displays': ids},
      );
      if (res.statusCode == 409) return (null, 'not_connected');
      if (res.statusCode != 200 || res.data is! Map) {
        return (null, 'O computador recusou (${res.statusCode}).');
      }
      return (SharedMonitor.listFrom((res.data as Map)['displays']), null);
    } on DioException {
      return (null, 'Computador fora do ar.');
    }
  }

  /// Mostra/esconde as janelas do computador (fundo preto de espera).
  static Future<void> visibility(MonitorShareTarget target, bool visible) async {
    try {
      await _dio.post<dynamic>(
        'http://${target.address}/monitor-share/visibility',
        data: {'token': target.token, 'visible': visible},
      );
    } on DioException {
      // Fora do ar: na próxima conexão o estado vai junto.
    }
  }

  static Future<void> disconnect(MonitorShareTarget target) async {
    try {
      await _dio.post<dynamic>(
        'http://${target.address}/monitor-share/disconnect',
        data: {'token': target.token},
      );
    } on DioException {
      // Computador já fora do ar: nada a fazer.
    }
  }
}

/// Leitor do QR "Compartilhar monitores" do desktop.
class MonitorShareScanPage extends StatefulWidget {
  const MonitorShareScanPage({super.key});

  @override
  State<MonitorShareScanPage> createState() => _MonitorShareScanPageState();
}

class _MonitorShareScanPageState extends State<MonitorShareScanPage> {
  bool _done = false;
  String? _hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler QR do computador')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final code in capture.barcodes) {
                final target = MonitorShareTarget.parse(code.rawValue ?? '');
                if (target != null) {
                  _done = true;
                  Navigator.pop(context, target);
                  return;
                }
              }
              setState(
                () => _hint =
                    'Este QR não é o de "Compartilhar monitores" do app.',
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _hint ??
                      'No computador: Configurações › Projeção & Telas › '
                          'Compartilhar monitores com app mobile.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
