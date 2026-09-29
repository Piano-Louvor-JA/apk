library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:louvorja_piano_mobile/presentation/remote/unified_qr_scanner.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Seção "Controle Remoto" das Configurações.
///
/// Dois fluxos (SPEC 2026-08-16-controle-remoto-apk):
/// - Desktop: operador digita IP:porta do Electron → APK conecta (cliente).
/// - Web: APK sobe servidor WS e mostra a URL `ws://…?t=…` para abrir no
///   navegador do desktop (browser não aceita conexão de entrada).
///
/// Conectado: controles do player do alvo (play/pause/prev/next/stop,
/// volume) espelhando o estado recebido em tempo real.
class RemoteSection extends StatefulWidget {
  const RemoteSection({super.key, this.session});

  /// Injetável para testes; default = singleton global.
  final RemoteSession? session;

  @override
  State<RemoteSection> createState() => _RemoteSectionState();
}

class _RemoteSectionState extends State<RemoteSection> {
  RemoteSession get _session => widget.session ?? RemoteSession.instance;

  final _hostCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  var _hostValid = false;
  var _tokenValid = false;

  StreamSubscription? _statusSub;
  RemoteSessionStatus? _status;
  String? _webUrl;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl.addListener(_validateHost);
    _tokenCtrl.addListener(_validateToken);
    _statusSub = _session.status.listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  void _validateHost() {
    final raw = _hostCtrl.text.trim();
    // Aceita: IP (ex: 192.168.1.192) ou IP:porta (ex: 192.168.1.192:7070)
    final valid = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d{2,5})?$').hasMatch(raw);
    if (valid != _hostValid) setState(() => _hostValid = valid);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _hostCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _validateToken() {
    final raw = _tokenCtrl.text.trim();
    final valid = RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(raw);
    if (valid != _tokenValid) setState(() => _tokenValid = valid);
  }

  /// QR do desktop: louvorja://connect?host=IP:PORTA&token=XXXX
  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const DesktopQrScannerPage()),
    );
    if (code == null) return;
    // QR do web (P2P WebRTC): JSON {type:'offer', sdp:...}
    final trimmed = code.trim();
    if (trimmed.startsWith('{')) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => P2pPairingFromScanPage(offerJson: trimmed),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(code);
    if (uri == null || uri.scheme != 'louvorja') {
      _snack('remote.qrInvalid'.tr());
      return;
    }
    final host = uri.queryParameters['host'];
    final token = uri.queryParameters['token'];
    if (host == null || token == null) {
      _snack('remote.qrInvalid'.tr());
      return;
    }
    setState(() {
      _hostCtrl.text = host;
      _tokenCtrl.text = token;
    });
    _validateHost();
    _validateToken();

    // Conecta AUTOMÁTICO — ler o QR já significa "quero conectar agora".
    await _connectDesktop();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _connectDesktop() async {
    final parts = _hostCtrl.text.trim().split(':');
    final host = parts[0];
    final port = parts.length > 1 ? int.parse(parts[1]) : 7071;
    setState(() => _busy = true);
    final ok = await _session.connectDesktop(
      host: host,
      port: port,
      token: _tokenCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao desktop.')),
      );
    }
  }

  Future<void> _startWebLink() async {
    setState(() => _busy = true);
    final url = await _session.startWebLink(
      token: RemotePairing.generateToken(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _webUrl = url;
    });
  }

  Future<void> _disconnect() async {
    await _session.disconnect();
    if (!mounted) return;
    setState(() {
      _webUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final connected =
        _session.mode != RemoteMode.idle &&
        (_status == RemoteSessionStatus.connected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(TablerIcons.cast, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'remote.title'.tr(),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('remote.subtitle'.tr(), style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_session.mode == RemoteMode.idle) ...[
          TextField(
            key: const Key('remote-host'),
            controller: _hostCtrl,
            decoration: InputDecoration(
              labelText: 'remote.desktop_host'.tr(),
              hintText: 'remote.desktop_hint'.tr(),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.url,
            enabled: !_busy,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('remote-token'),
            controller: _tokenCtrl,
            decoration: InputDecoration(
              labelText: 'remote.token'.tr(),
              hintText: 'XXXXXX',
              border: const OutlineInputBorder(),
              isDense: true,
              counterText: '',
            ),
            maxLength: 12,
            textCapitalization: TextCapitalization.characters,
            enabled: !_busy,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('remote-scan-qr'),
            onPressed: !_busy ? _scanQr : null,
            icon: const Icon(TablerIcons.qrcode),
            label: Text('remote.scanQr'.tr()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('remote-connect'),
                  onPressed: _hostValid && !_busy ? _connectDesktop : null,
                  icon: const Icon(TablerIcons.plugConnected),
                  label: Text('remote.connect'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('remote-weblink'),
                  onPressed: !_busy ? _startWebLink : null,
                  icon: const Icon(TablerIcons.world),
                  label: Text(
                    'remote.start_weblink'.tr(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          _buildActivePanel(theme, connected),
        ],
      ],
    );
  }

  Widget _buildActivePanel(ThemeData theme, bool connected) {
    final modeLabel = _session.mode == RemoteMode.desktop
        ? 'remote.mode_desktop'.tr()
        : 'remote.mode_web'.tr();
    final statusLabel = switch (_status) {
      RemoteSessionStatus.connected => 'remote.status_connected'.tr(),
      RemoteSessionStatus.connecting => 'remote.status_connecting'.tr(),
      RemoteSessionStatus.listening => 'remote.status_listening'.tr(),
      _ => 'remote.status_disconnected'.tr(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$modeLabel · $statusLabel',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: connected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              key: const Key('remote-disconnect'),
              tooltip: 'remote.disconnect'.tr(),
              onPressed: _disconnect,
              icon: const Icon(TablerIcons.plugConnectedX),
            ),
          ],
        ),
        if (_session.mode == RemoteMode.web &&
            _status == RemoteSessionStatus.listening &&
            _webUrl != null) ...[
          const SizedBox(height: 8),
          // QR único: web escaneia com a webcam e conecta direto no WS.
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: _webUrl!,
                size: 220,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('remote.weblink_url'.tr(), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          InkWell(
            key: const Key('remote-weblink-url'),
            onTap: () => Clipboard.setData(ClipboardData(text: _webUrl!)),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _webUrl!.replaceFirst('ws://', ''),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('remote.weblink_waiting'.tr(), style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        // Controles migraram para Ferramentas > Controle Remoto.
        Text('remote.controlsMoved'.tr(), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Página de leitura do QR de emparelhamento do desktop.
class DesktopQrScannerPage extends StatefulWidget {
  const DesktopQrScannerPage();

  @override
  State<DesktopQrScannerPage> createState() => _DesktopQrScannerPageState();
}

class _DesktopQrScannerPageState extends State<DesktopQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _popped = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_popped || !mounted) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _popped = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('remote.scanQr'.tr()),
        actions: [
          IconButton(
            icon: Icon(_torch ? TablerIcons.boltOff : TablerIcons.bolt),
            tooltip: 'remote.torch'.tr(),
            onPressed: () {
              setState(() => _torch = !_torch);
              _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('remote.cameraError'.tr(), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
