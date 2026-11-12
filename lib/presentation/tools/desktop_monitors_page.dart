library;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/services/dlna/slide_http_server.dart';
import '../../core/services/dlna/stage_session.dart';
import '../../core/services/palco/palco_controller.dart' show PalcoTarget;
import '../../core/services/palco/palco_orchestrator.dart';
import 'monitor_share_link.dart';

/// Conectar monitor: usar os monitores do app desktop como telas do
/// celular (paridade com Projeção & Telas › Compartilhar monitores).
class DesktopMonitorsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const DesktopMonitorsPage({super.key, this.onBack});

  @override
  State<DesktopMonitorsPage> createState() => _DesktopMonitorsPageState();
}

class _DesktopMonitorsPageState extends State<DesktopMonitorsPage> {
  final _orch = PalcoOrchestrator.instance;
  MonitorShareTarget? _desktop;
  int _monitors = 0;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final session = MonitorShareSession.instance;
    if (session.connected && session.target != null) {
      _desktop = session.target;
      _monitors = session.monitors.where((m) => m.active).length;
    }
    MonitorShareLink.saved().then((t) {
      if (mounted && t != null && _desktop == null) setState(() => _desktop = t);
    });
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// O celular precisa estar no ar (Principal) para os monitores
  /// receberem: liga o palco do app, igual à Transmissão.
  Future<int?> _ensurePrincipal() async {
    await _orch.loadStoredConfig();
    if (_orch.slot('principal') == null) {
      _orch.addSlot(id: 'principal', label: 'Principal');
    }
    final principal = _orch.slot('principal')!;
    await SlideHttpServer.resolveLocalIp();
    final ip = SlideHttpServer.localIp;
    if (ip == null) {
      _error = 'Sem rede Wi-Fi: conecte o celular à rede do computador.';
      return null;
    }
    if (!principal.controller.isRunning) {
      final ok = await StageSession.instance.turnOnPalco(
        PalcoTarget(name: principal.label, ip: ip, wsPort: principal.wsPort),
      );
      if (!ok) {
        _error = 'A porta ${principal.httpPort} está em uso no celular.';
        return null;
      }
    }
    return principal.wsPort;
  }

  Future<void> _connect(MonitorShareTarget target) => _run(() async {
    _error = null;
    final wsPort = await _ensurePrincipal();
    final ip = SlideHttpServer.localIp;
    if (wsPort == null || ip == null) {
      setState(() {});
      return;
    }
    final session = MonitorShareSession.instance;
    await session.loadHideIdle();
    final (n, error) = await MonitorShareLink.connect(
      target,
      phoneIp: ip,
      wsPort: wsPort,
      visible: session.windowsVisible,
    );
    setState(() {
      _desktop = target;
      _monitors = n;
      _error = error;
    });
    if (n > 0) {
      MonitorShareSession.instance.markConnected(target);
    } else {
      MonitorShareSession.instance.markDisconnected();
    }
  });

  Future<void> _scan() async {
    final target = await Navigator.of(context).push<MonitorShareTarget>(
      MaterialPageRoute(builder: (_) => const MonitorShareScanPage()),
    );
    if (target != null) await _connect(target);
  }

  Future<void> _type() async {
    final saved = _desktop;
    final address = TextEditingController(
      text: saved?.address.replaceAll(':48090', '') ?? '',
    );
    final code = TextEditingController(text: saved?.token ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endereço do computador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: address,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                hintText: '192.168.0.130',
              ),
            ),
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código (6 letras)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final target = MonitorShareTarget.manual(address.text, code.text);
    if (target == null) {
      setState(() => _error = 'Confira o endereço e o código de 6 letras.');
      return;
    }
    await _connect(target);
  }

  Future<void> _disconnect() => _run(() async {
    final target = _desktop;
    if (target != null) await MonitorShareLink.disconnect(target);
    MonitorShareSession.instance.markDisconnected();
    setState(() {
      _monitors = 0;
      _error = null;
    });
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = _monitors > 0;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(TablerIcons.arrowLeft),
                onPressed: widget.onBack,
              ),
        title: const Text('Conectar monitor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        connected ? TablerIcons.circleCheck : TablerIcons.devicesPc,
                        color: connected
                            ? Colors.greenAccent.shade400
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          connected
                              ? 'Conectado a ${_desktop!.address.split(':').first} · $_monitors monitor(es) em uso'
                              : _desktop == null
                              ? 'Nenhum computador conectado'
                              : 'Último: ${_desktop!.address.split(':').first} · desconectado',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (_busy)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(_error!, style: theme.textTheme.bodySmall),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('desktop-monitors-scan'),
                      onPressed: _busy ? null : _scan,
                      icon: const Icon(TablerIcons.qrcode),
                      label: const Text('Ler QR do computador'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _type,
                      icon: const Icon(TablerIcons.keyboard),
                      label: const Text('Digitar endereço e código'),
                    ),
                  ),
                  if (_desktop != null && !connected) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _connect(_desktop!),
                        icon: const Icon(TablerIcons.refresh),
                        label: const Text('Reconectar ao último'),
                      ),
                    ),
                  ],
                  if (connected) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _disconnect,
                        icon: const Icon(TablerIcons.plugConnectedX),
                        label: const Text('Desconectar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Como funciona',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Use as TVs, monitores e projetores ligados por CABO (HDMI, '
            'VGA, DisplayPort) ao computador como telas do celular — sem '
            'precisar de TV com app Palco.\n\n'
            '1. No computador: Configurações › Projeção & Telas › '
            'Compartilhar monitores com app mobile — ligue e escolha os '
            'monitores (Espelho ou Retorno).\n'
            '2. Aqui: leia o QR que aparece lá (ou digite o endereço e o '
            'código).\n'
            '3. Toque hinos, Bíblia ou cronômetro: aparecem nos monitores do '
            'computador. O som continua no celular.\n'
            'Celular e computador precisam estar na mesma rede.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
