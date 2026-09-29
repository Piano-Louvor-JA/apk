// Scanner QR unificado — detecta: WS legacy (ws://) ou SDP P2P ({sdp,type})
library;

import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:louvorja_piano_mobile/core/services/remote/desktop_connection.dart';
import 'package:louvorja_piano_mobile/core/services/remote/p2p_remote_client.dart';

enum QrType { unknown, wsLegacy, p2pOffer }

class UnifiedQrScanner extends StatefulWidget {
  const UnifiedQrScanner({super.key});

  @override
  State<UnifiedQrScanner> createState() => _UnifiedQrScannerState();
}

class _UnifiedQrScannerState extends State<UnifiedQrScanner> {
  // (tipo detectado apenas para roteamento imediato — sem estado extra)
  String? _rawValue;
  final controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  QrType _classify(String v) {
    if (v.startsWith('ws://')) return QrType.wsLegacy;
    try {
      final m = Map<String, dynamic>.from(json.decode(v));
      if (m.containsKey('sdp') && m.containsKey('type')) return QrType.p2pOffer;
    } catch (_) {}
    return QrType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('remote.scanQr'.tr())),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v == null || v == _rawValue) continue;
                _rawValue = v;
                final type = _classify(v);
                controller.stop();
                _route(type, v);
                break;
              }
            },
          ),
        ],
      ),
    );
  }

  void _route(QrType type, String value) {
    if (type == QrType.wsLegacy) {
      Navigator.of(context).pop();
      _connectWsLegacy(value);
    } else if (type == QrType.p2pOffer) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => P2pPairingFromScanPage(offerJson: value),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => P2pPairingFromScanPage(offerJson: value),
        ),
      );
    }
  }

  Future<void> _connectWsLegacy(String wsUrl) async {
    final uri = Uri.parse(wsUrl);
    final host = uri.host;
    final port = uri.port;
    final token = uri.queryParameters['t'] ?? '';
    await DesktopConnection().connect(host: host, port: port, token: token);
  }
}

class P2pPairingFromScanPage extends StatefulWidget {
  final String offerJson;
  const P2pPairingFromScanPage({super.key, required this.offerJson});
  @override
  State<P2pPairingFromScanPage> createState() => _P2pPairingFromScanPageState();
}

class _P2pPairingFromScanPageState extends State<P2pPairingFromScanPage> {
  String? _answerJson;
  String _log = '';
  late P2pRemoteClient _client;

  @override
  void initState() {
    super.initState();
    _client = P2pRemoteClient(
      onOpen: () {
        if (mounted) setState(() => _log = 'liturgy.p2p.connected'.tr());
      },
      onClose: () {
        if (mounted) setState(() => _log = 'liturgy.p2p.disconnected'.tr());
      },
      onMessage: (m) {
        if (mounted) setState(() => _log = '← ${m['action'] ?? m}');
      },
    );
    _negotiate();
  }

  Future<void> _negotiate() async {
    setState(() => _log = 'liturgy.p2p.negotiating'.tr());
    final answer = await _client.acceptOffer(widget.offerJson);
    if (answer == null) {
      setState(() => _log = 'liturgy.p2p.badOffer'.tr());
      return;
    }
    if (mounted) setState(() => _answerJson = answer);
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('liturgy.p2p.title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('liturgy.p2p.hintShow'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: _answerJson != null
                    ? QrImageView(
                        data: _answerJson!,
                        size: 280,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            if (_answerJson != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        'liturgy.p2p.copyFallback'.tr(),
                        style: theme.textTheme.labelSmall,
                      ),
                      SelectableText(
                        _answerJson!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            if (_log.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _log,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
