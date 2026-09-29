// Pareamento P2P (WebRTC 2-QR) — APK escaneia offer do web e mostra answer.
library;

import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/remote/p2p_remote_client.dart';

class P2pPairingPage extends StatefulWidget {
  const P2pPairingPage({super.key});

  @override
  State<P2pPairingPage> createState() => _P2pPairingPageState();
}

enum _P2pStep { scan, showAnswer, connected }

class _P2pPairingPageState extends State<P2pPairingPage> {
  _P2pStep _step = _P2pStep.scan;
  String? _answerJson;
  String _log = '';
  P2pRemoteClient? _client;

  void _push(String msg) {
    if (mounted) setState(() => _log = msg);
  }

  Future<void> _onScan(String offerJson) async {
    if (_step != _P2pStep.scan) return;
    _push('liturgy.p2p.negotiating'.tr());
    final client = P2pRemoteClient(
      onOpen: () {
        _push('liturgy.p2p.connected'.tr());
        if (mounted) setState(() => _step = _P2pStep.connected);
      },
      onClose: () => _push('liturgy.p2p.disconnected'.tr()),
      onMessage: (m) => _push('← ${m['action'] ?? m}'),
    );
    final answer = await client.acceptOffer(offerJson);
    if (answer == null) {
      _push('liturgy.p2p.badOffer'.tr());
      return;
    }
    _client = client;
    if (!mounted) return;
    setState(() {
      _answerJson = answer;
      _step = _P2pStep.showAnswer;
    });
  }

  @override
  void dispose() {
    _client?.dispose();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _step == _P2pStep.scan
                  ? 'liturgy.p2p.hintScan'.tr()
                  : _step == _P2pStep.showAnswer
                  ? 'liturgy.p2p.hintShow'.tr()
                  : 'liturgy.p2p.connected'.tr(),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_step == _P2pStep.scan && !kIsWeb && Platform.isAndroid ||
                _step == _P2pStep.scan && !kIsWeb && Platform.isIOS)
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final b in barcodes) {
                      final v = b.rawValue;
                      if (v != null && v.contains('"sdp"')) {
                        _onScan(v);
                        break;
                      }
                    }
                  },
                ),
              )
            else if (_step == _P2pStep.scan)
              Expanded(
                child: Center(
                  child: Text('liturgy.p2p.scannerUnavailable'.tr()),
                ),
              ),
            if (_step == _P2pStep.showAnswer && _answerJson != null) ...[
              Expanded(
                child: Center(
                  child: QrImageView(
                    data: _answerJson!,
                    size: 280,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
              ),
              // SDP é grande: QR pode passar do limite. Texto é o fallback
              // garantido — usuário copia e cola no web.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        'liturgy.p2p.copyFallback'.tr(),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
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
            ],
            if (_step == _P2pStep.connected)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TablerIcons.plugConnected,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text('liturgy.p2p.connected'.tr()),
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
