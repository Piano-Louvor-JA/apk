library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/palco/palco_controller.dart' show PalcoTarget;

import '../../../core/services/dlna/stage_session.dart';
import '../../../core/services/dlna/palco_mdns_discovery.dart';
import '../../../core/services/dlna/palco_wake.dart';
import '../../../core/services/dlna/webos_tv_dial_probe.dart';
import '../../../core/services/dlna/slide_http_server.dart';

/// F3.3ae: tela de conexão AUTO-FIRST do Palco.
///
/// Ao abrir: liga o sender JÁ, escaneia TVs webOS (DIAL 1926) em paralelo e
/// mostra o estado ao vivo. O receiver da TV conecta sozinho no sender —
/// quando conecta, esta tela fecha sozinha. IP manual (tecla vermelha na
/// TV) permanece como fallback discreto.
class PalcoAutoConnectSheet extends StatefulWidget {
  const PalcoAutoConnectSheet({super.key});

  @override
  State<PalcoAutoConnectSheet> createState() => _PalcoAutoConnectSheetState();
}

class _PalcoAutoConnectSheetState extends State<PalcoAutoConnectSheet> {
  String? _tvName;
  String? _tvIp;
  bool _scanningTv = true;
  bool _senderOn = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _start();
    StageSession.instance.addListener(_onSession);
  }

  @override
  void dispose() {
    StageSession.instance.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final s = StageSession.instance;
    if (s.isPalcoMode && (s.palco?.isConnected ?? false) && mounted) {
      setState(() => _connected = true);
      // conectou! fecha sozinho após feedback
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> _start() async {
    // 1. liga o sender imediatamente (o receiver conecta nele)
    await SlideHttpServer.resolveLocalIp();
    final localIp = SlideHttpServer.localIp;
    if (localIp == null || !mounted) return;
    final ok = await StageSession.instance.turnOnPalco(
      PalcoTarget(name: 'Palco (aguardando TV)', ip: localIp),
    );
    if (mounted) setState(() => _senderOn = ok);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('palco_last_ip', localIp);
    if (!ok || !mounted) return;

    // já conectou instantâneo (TV com Palco aberto)? o listener cuida.

    // F3.4 fase 2: mDNS primeiro (instantâneo — Android TV via NSD);
    // DIAL 1926 como fallback (LG sem NSD). Multicast cego = fallback.
    var tvs = <WebosTv>[];
    try {
      tvs = await PalcoMdnsDiscovery.scan();
    } catch (_) {
      /* mDNS bloqueado — segue pro fallback */
    }
    if (tvs.isEmpty) {
      try {
        tvs = await WebosTvDialProbe.scan();
      } catch (_) {
        /* nenhuma TV */
      }
    }
    if (mounted) {
      setState(() {
        _scanningTv = false;
        if (tvs.isNotEmpty) {
          _tvName = tvs.first.friendlyName;
          _tvIp = tvs.first.ip;
        }
      });
    }
    // F3.4 fase 3a (RF-003): TV detectada mas receiver não conectou em 3s
    // → WAKE (Android TV abre o Palco sozinha; LG ignora em silêncio).
    if (tvs.isNotEmpty && !_connected) {
      Future<void>.delayed(const Duration(seconds: 3), () async {
        if (_connected || _tvIp == null) return;
        final delivered = await PalcoWake.send(_tvIp!);
        if (delivered && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Abrindo o Palco na TV…'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localIp = SlideHttpServer.localIp ?? '…';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'stage.title'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // estado 1: sender
            _StatusRow(
              icon: _senderOn ? Icons.check_circle : Icons.hourglass_top,
              color: _senderOn ? Colors.green : Colors.orange,
              text: _senderOn
                  ? 'Sender ativo em $localIp'
                  : 'Ligando o sender…',
            ),
            const SizedBox(height: 8),
            // estado 2: TV detectada
            if (_scanningTv)
              const _StatusRow(
                icon: Icons.search,
                color: Colors.orange,
                text: 'Procurando TV webOS na rede…',
              )
            else if (_tvName != null)
              _StatusRow(
                icon: Icons.tv,
                color: Colors.blue,
                text: 'TV detectada: $_tvName ($_tvIp)',
              )
            else
              const _StatusRow(
                icon: Icons.tv_off,
                color: Colors.grey,
                text: 'Nenhuma TV webOS na rede',
              ),
            const SizedBox(height: 8),
            // estado 3: aguardando receiver
            if (!_connected)
              const _StatusRow(
                icon: Icons.cast_connected,
                color: Colors.orange,
                text: 'Abra o app Palco na TV — ele conecta sozinho',
              )
            else
              const _StatusRow(
                icon: Icons.check_circle,
                color: Colors.green,
                text: 'TV conectada — projetando!',
              ),
            const Divider(height: 24),
            // fallback manual: IP do celular (tecla vermelha na TV)
            Text(
              'Se a TV não conectar: tecla VERMELHA no controle do Palco → digite',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    localIp,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar IP',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: localIp));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('IP copiado: $localIp')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
