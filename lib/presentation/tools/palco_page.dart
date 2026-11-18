library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/services/dlna/palco_mdns_discovery.dart';
import '../../core/services/dlna/palco_wake.dart';
import '../../core/services/dlna/slide_http_server.dart';
import '../../core/services/dlna/webos_tv_dial_probe.dart';
import '../../core/services/palco/palco_orchestrator.dart';
import '../../core/services/palco/palco_sender.dart'
    show PalcoClientInfo, PalcoSender;
import '../../core/services/palco/palco_slot.dart';
import '../settings/widgets/stage_section.dart';
import 'transmission_page.dart';

/// Palco: TVs com o app Palco (webOS, Tizen, Android TV). Mostra quais
/// estão conectadas a cada transmissão e as TVs
/// encontradas na rede que ainda não conectaram.
class PalcoPage extends StatefulWidget {
  final VoidCallback? onBack;

  const PalcoPage({super.key, this.onBack});

  @override
  State<PalcoPage> createState() => _PalcoPageState();
}

class _PalcoPageState extends State<PalcoPage> {
  final _orch = PalcoOrchestrator.instance;
  String? _ip;
  bool _scanning = false;
  List<WebosTv> _found = const [];
  final Set<String> _waking = {};

  @override
  void initState() {
    super.initState();
    _orch.addListener(_onChanged);
    _init();
  }

  Future<void> _init() async {
    await _orch.loadStoredConfig();
    await SlideHttpServer.resolveLocalIp();
    if (mounted) setState(() => _ip = SlideHttpServer.localIp);
    await _scan();
  }

  @override
  void dispose() {
    _orch.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// mDNS (Android TV anuncia `_palco._tcp`) e porta 1926 (TV LG) em
  /// paralelo; junta por IP.
  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    final results = await Future.wait([
      PalcoMdnsDiscovery.scan().catchError((_) => <WebosTv>[]),
      WebosTvDialProbe.scan().catchError((_) => <WebosTv>[]),
    ]);
    final byIp = <String, WebosTv>{};
    for (final list in results) {
      for (final tv in list) {
        byIp.putIfAbsent(tv.ip, () => tv);
      }
    }
    if (!mounted) return;
    setState(() {
      _found = byIp.values.toList();
      _scanning = false;
    });
  }

  Future<void> _wake(WebosTv tv) async {
    setState(() => _waking.add(tv.ip));
    final ok = await PalcoWake.send(tv.ip);
    if (!mounted) return;
    setState(() => _waking.remove(tv.ip));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Abrindo o Palco em ${tv.friendlyName}…'
              : 'Abra o app Palco na TV pelo controle remoto.',
        ),
      ),
    );
  }

  void _openTransmission() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TransmissionPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _orch.slots.where((s) => s.controller.isRunning).toList();
    final connected = palcoConnections();
    final connectedIps = {for (final c in connected) c.$2.ip};
    final notConnected = _found
        .where((tv) => !connectedIps.contains(tv.ip))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                key: const Key('tool-back'),
                icon: const Icon(TablerIcons.arrowLeft),
                onPressed: widget.onBack,
              ),
        title: const Text('Palco'),
        actions: [
          IconButton(
            key: const Key('palco-scan'),
            tooltip: 'Procurar TVs na rede',
            onPressed: _scanning ? null : _scan,
            icon: const Icon(TablerIcons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (running.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(TablerIcons.broadcastOff),
                title: const Text('Nenhuma transmissão no ar'),
                subtitle: const Text(
                  'As TVs com o Palco só conectam quando o celular está '
                  'transmitindo.',
                ),
                trailing: FilledButton(
                  key: const Key('palco-open-transmission'),
                  onPressed: _openTransmission,
                  child: const Text('Ligar'),
                ),
              ),
            ),
          _SectionTitle(
            'Conectados',
            trailing: running.isEmpty ? null : '${connected.length}',
          ),
          if (connected.isEmpty)
            _Hint(
              running.isEmpty
                  ? 'Ligue a transmissão para as TVs conectarem.'
                  : 'Nenhum palco conectado. Abra o app Palco na TV: ele '
                        'procura o celular na rede sozinho.',
            )
          else
            const PalcoConnectedList(),
          const SizedBox(height: 12),
          _SectionTitle(
            'Detectados na rede',
            trailing: _scanning ? null : '${notConnected.length}',
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Procurando TVs na rede…'),
                ],
              ),
            )
          else if (notConnected.isEmpty)
            const _Hint(
              'Nenhuma outra TV encontrada. Android TV com o Palco e TVs LG '
              'aparecem aqui quando estão na mesma rede Wi-Fi.',
            )
          else
            for (final tv in notConnected)
              ListTile(
                key: Key('palco-found-${tv.ip}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(TablerIcons.deviceTv),
                title: Text(tv.friendlyName),
                subtitle: Text('${tv.ip} · não conectado'),
                trailing: TextButton(
                  onPressed: _waking.contains(tv.ip) ? null : () => _wake(tv),
                  child: const Text('Abrir Palco'),
                ),
              ),
          const Divider(height: 32),
          Text(
            'A TV não achou o celular? No app Palco, aperte a tecla '
            'VERMELHA do controle e digite:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _ip ?? 'sem rede Wi-Fi',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_ip != null)
                IconButton(
                  tooltip: 'Copiar IP',
                  icon: const Icon(TablerIcons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _ip!));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('IP copiado: $_ip')));
                  },
                ),
            ],
          ),
          const Divider(height: 32),
          const _SectionTitle('Configurações'),
          const SizedBox(height: 4),
          const StageSection(),
        ],
      ),
    );
  }
}

IconData _platformIcon(String platform) => switch (platform) {
  'obs' => TablerIcons.video,
  'browser' => TablerIcons.browser,
  _ => TablerIcons.deviceTv,
};

/// Pares (transmissão, TV) de todas as transmissões no ar. Só TVs com o
/// app Palco: abas de navegador e OBS ficam em Conexões remotas.
List<(PalcoSlot, PalcoClientInfo)> palcoConnections() => [
  for (final s in PalcoOrchestrator.instance.slots)
    if (s.controller.isRunning)
      for (final c in s.controller.clients)
        if (c.isTv) (s, c),
];

/// Palcos conectados, com o menu de ações por TV (identificar, renomear,
/// mover de transmissão, recarregar). Usado na página Palco e no painel de
/// conexões do player.
class PalcoConnectedList extends StatefulWidget {
  const PalcoConnectedList({super.key, this.dense = false});

  final bool dense;

  @override
  State<PalcoConnectedList> createState() => _PalcoConnectedListState();
}

class _PalcoConnectedListState extends State<PalcoConnectedList> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PalcoOrchestrator.instance,
    builder: (context, _) {
      final running = PalcoOrchestrator.instance.slots
          .where((s) => s.controller.isRunning)
          .toList();
      return Column(
        children: [
          for (final (slot, c) in palcoConnections())
            _tile(context, slot, c, running),
        ],
      );
    },
  );

  /// ✓ = recebe a transmissão. Desmarcada: continua conectada, na espera.
  Widget _tile(
    BuildContext context,
    PalcoSlot slot,
    PalcoClientInfo c,
    List<PalcoSlot> running,
  ) {
    final theme = Theme.of(context);
    final orch = PalcoOrchestrator.instance;
    final muted = orch.isTvMuted(c);
    return CheckboxListTile(
      key: ObjectKey(c),
      dense: widget.dense,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: !muted,
      onChanged: (v) => orch.setTvMuted(c, v != true),
      title: Text(
        c.name,
        key: Key('palco-tv-${PalcoSender.muteKey(c)}'),
        style: muted
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(
        [
          c.ip,
          slot.label,
          if (c.version != null) 'v${c.version}',
          if (muted) 'na espera',
        ].join(' · '),
      ),
      secondary: IconButton(
        tooltip: 'Ações da TV',
        icon: const Icon(TablerIcons.dotsVertical, size: 20),
        onPressed: () => _openActions(slot, c, running),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static const _gone = 'Essa TV saiu da transmissão.';

  /// Ações de um palco conectado: identificar, renomear, mover de
  /// transmissão e recarregar. Receivers sem `hello` (antigos) não entendem
  /// os comandos: as ações aparecem desligadas com o aviso de atualizar.
  Future<void> _openActions(
    PalcoSlot slot,
    PalcoClientInfo c,
    List<PalcoSlot> running,
  ) async {
    final supported = c.version != null;
    final others = running.where((s) => s != slot).toList();
    final ctl = slot.controller;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(_platformIcon(c.platform)),
              title: Text(c.name, style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: Text('${c.ip} · ${slot.label}'),
            ),
            if (!supported)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Atualize o app Palco nesta TV para usar estas ações.',
                ),
              ),
            const Divider(height: 1),
            ListTile(
              key: const Key('palco-action-identify'),
              enabled: supported,
              leading: const Icon(TablerIcons.eye),
              title: const Text('Identificar'),
              subtitle: const Text('Mostra o nome desta TV na tela dela'),
              onTap: () => Navigator.pop(ctx, 'identify'),
            ),
            ListTile(
              key: const Key('palco-action-rename'),
              enabled: supported,
              leading: const Icon(TablerIcons.pencil),
              title: const Text('Renomear'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            for (final o in others)
              ListTile(
                key: Key('palco-action-move-${o.id}'),
                enabled: supported,
                leading: const Icon(TablerIcons.arrowsExchange),
                title: Text('Mover para ${o.label}'),
                onTap: () => Navigator.pop(ctx, 'move:${o.id}'),
              ),
            ListTile(
              key: const Key('palco-action-reload'),
              enabled: supported,
              leading: const Icon(TablerIcons.reload),
              title: const Text('Recarregar o Palco'),
              subtitle: const Text('Reabre o app na TV e reconecta'),
              onTap: () => Navigator.pop(ctx, 'reload'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'identify':
        _toast(
          ctl.identifyClient(c, slotLabel: slot.label)
              ? 'Olhe as TVs: o nome aparece em ${c.name}.'
              : _gone,
        );
      case 'rename':
        final name = await _askName(c.name);
        if (name == null) return;
        _toast(ctl.renameClient(c, name) ? 'TV renomeada para $name.' : _gone);
      case 'reload':
        _toast(ctl.reloadClient(c) ? 'Recarregando ${c.name}…' : _gone);
      default:
        final target = others.where((o) => 'move:${o.id}' == action);
        if (target.isEmpty) return;
        final to = target.first;
        _toast(
          ctl.moveClient(c, to.wsPort)
              ? '${c.name} vai para ${to.label}.'
              : _gone,
        );
    }
  }

  Future<String?> _askName(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(current: current),
    );
    final n = name?.trim();
    return (n == null || n.isEmpty || n == current) ? null : n;
  }
}

/// Dono do campo de texto: o controller só é descartado depois da animação
/// de saída do diálogo (descartar logo após o pop quebra a tela).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});
  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _text = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nome da TV'),
    content: TextField(
      key: const Key('palco-rename-field'),
      controller: _text,
      autofocus: true,
      maxLength: 40,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Ex.: TV do púlpito'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('Salvar'),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
