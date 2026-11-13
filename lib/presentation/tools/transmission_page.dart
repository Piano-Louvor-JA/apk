library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/services/dlna/slide_http_server.dart';
import '../../core/services/dlna/stage_session.dart';
import '../../core/services/palco/palco_controller.dart' show PalcoTarget;
import '../../core/services/palco/palco_orchestrator.dart';
import '../../core/services/palco/palco_slot.dart';

/// Transmissão (paridade com Configurações › Transmissão do desktop):
/// conexões do celular como servidor do palco — cada uma com porta própria
/// (4980/4981, 4982/4983…), link da legenda para o OBS e link do receiver.
class TransmissionPage extends StatefulWidget {
  final VoidCallback? onBack;

  const TransmissionPage({super.key, this.onBack});

  @override
  State<TransmissionPage> createState() => _TransmissionPageState();
}

class _TransmissionPageState extends State<TransmissionPage> {
  final _orch = PalcoOrchestrator.instance;
  String? _ip;
  String? _busy;
  final Map<String, String> _errors = {};

  /// Tipo de cada conexão extra (paridade desktop): 'mirror' = Espelho do
  /// Palco (/espelho) ou 'return' = Retorno de palco (/retorno).
  static const _kindsKey = 'transmission_kinds';
  Map<String, String> _kinds = {};

  Future<void> _loadKinds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kindsKey) ?? const [];
    final map = <String, String>{};
    for (final e in raw) {
      final i = e.indexOf('=');
      if (i > 0) map[e.substring(0, i)] = e.substring(i + 1);
    }
    if (mounted) setState(() => _kinds = map);
  }

  Future<void> _setKind(String slotId, String kind) async {
    setState(() => _kinds = {..._kinds, slotId: kind});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kindsKey, [
      for (final e in _kinds.entries) '${e.key}=${e.value}',
    ]);
  }

  @override
  void initState() {
    super.initState();
    _orch.addListener(_onChanged);
    _init();
    _loadKinds();
  }

  Future<void> _init() async {
    await _orch.loadStoredConfig();
    if (_orch.slots.isEmpty) {
      _orch.addSlot(id: 'principal', label: 'Principal');
    }
    await SlideHttpServer.resolveLocalIp();
    if (mounted) setState(() => _ip = SlideHttpServer.localIp);
  }

  @override
  void dispose() {
    _orch.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run(String key, Future<void> Function() task) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<bool> _start(PalcoSlot slot) async {
    await SlideHttpServer.resolveLocalIp();
    final ip = SlideHttpServer.localIp;
    if (ip == null) {
      _errors[slot.id] = 'Sem rede Wi-Fi: conecte o celular à rede local.';
      return false;
    }
    final target = PalcoTarget(name: slot.label, ip: ip, wsPort: slot.wsPort);
    // A Principal liga o palco do app (igual ao botão de transmitir): sem
    // isso hinos/Bíblia/cronômetro não projetam e a legenda fica vazia.
    final ok = slot.id == 'principal'
        ? await StageSession.instance.turnOnPalco(target)
        : await _orch.connectTv(slot.id, target);
    if (ok) {
      _errors.remove(slot.id);
    } else {
      _errors[slot.id] =
          'A porta ${slot.httpPort} está em uso por outro programa.';
    }
    if (mounted) setState(() => _ip = ip);
    return ok;
  }

  Future<void> _stop(PalcoSlot slot) async {
    if (slot.id != 'principal') return _orch.disconnectTv(slot.id);
    // Desligar o palco do app encerra todas: as outras que estavam no ar
    // voltam sozinhas (sem palco do app elas só esperam conteúdo).
    final others = _orch.slots
        .where((s) => s.id != 'principal' && s.controller.isRunning)
        .toList();
    await StageSession.instance.turnOff();
    for (final s in others) {
      await _start(s);
    }
  }

  Future<void> _toggle(PalcoSlot slot) => _run(slot.id, () async {
    if (slot.controller.isRunning) {
      await _stop(slot);
    } else {
      await _start(slot);
    }
  });

  Future<void> _startAll() => _run('all', () async {
    for (final s in _orch.slots) {
      if (!s.controller.isRunning) await _start(s);
    }
  });

  /// Recarregar = encerra e sobe de novo (TVs/OBS reconectam sozinhos).
  Future<void> _reloadAll() => _run('all', () async {
    for (final s in _orch.slots) {
      if (!s.controller.isRunning) continue;
      await _stop(s);
      await _start(s);
    }
  });

  Future<void> _stopAll() => _run('all', () async {
    for (final s in _orch.slots) {
      if (s.controller.isRunning) await _stop(s);
    }
  });

  Future<void> _add() async {
    if (_orch.slots.length >= PalcoOrchestrator.maxSlots) {
      _toast('Limite de ${PalcoOrchestrator.maxSlots} conexões.');
      return;
    }
    final controller = TextEditingController(
      text: 'Conexão ${_orch.slots.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar conexão'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome',
            helperText: 'Ex.: OBS, TV do salão',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final id = 'conexao-${DateTime.now().millisecondsSinceEpoch}';
    if (!_orch.addSlot(id: id, label: name.trim())) return;
    final slot = _orch.slots.where((s) => s.id == id).firstOrNull;
    if (slot != null) await _run(id, () => _start(slot));
  }

  Future<void> _remove(PalcoSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover “${slot.label}”?'),
        content: const Text(
          'A conexão é encerrada e sai da lista. TVs e OBS ligados a ela '
          'deixam de receber.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) await _orch.removeSlot(slot.id);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    _toast('Link copiado.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ordem de criação (índice/porta): a nova entra abaixo das existentes.
    final slots = [..._orch.slots]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final onAir = slots.where((s) => s.controller.isRunning).toList();
    final clients = onAir.fold<int>(
      0,
      (sum, s) => sum + s.controller.clientCount,
    );
    final busyAll = _busy != null;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(TablerIcons.arrowLeft),
                onPressed: widget.onBack,
              ),
        title: const Text('Transmissão'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(
                TablerIcons.pointFilled,
                size: 16,
                color: onAir.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : Colors.greenAccent.shade400,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  onAir.isEmpty
                      ? 'Fora do ar'
                      : clients == 0
                      ? 'No ar · Nenhum dispositivo conectado'
                      : 'No ar · $clients dispositivo(s) conectado(s)',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${onAir.length} de ${slots.length} no ar',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('transmission-add'),
                onPressed: busyAll ? null : _add,
                icon: const Icon(TablerIcons.plus, size: 18),
                label: const Text('Adicionar conexão'),
              ),
              OutlinedButton.icon(
                onPressed: busyAll ? null : _startAll,
                icon: const Icon(TablerIcons.playerPlay, size: 18),
                label: const Text('Iniciar todas'),
              ),
              OutlinedButton.icon(
                onPressed: busyAll || onAir.isEmpty ? null : _reloadAll,
                icon: const Icon(TablerIcons.refresh, size: 18),
                label: const Text('Recarregar todas'),
              ),
              OutlinedButton.icon(
                onPressed: busyAll || onAir.isEmpty ? null : _stopAll,
                icon: const Icon(TablerIcons.square, size: 18),
                label: const Text('Encerrar todas'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final slot in slots) ...[
            _ConnectionCard(
              slot: slot,
              ip: _ip,
              error: _errors[slot.id],
              busy: _busy == slot.id,
              canRemove: slots.length > 1,
              kind: _kinds[slot.id] ?? 'mirror',
              onKind: (k) => _setKind(slot.id, k),
              onToggle: () => _toggle(slot),
              onRemove: () => _remove(slot),
              onCopy: _copy,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'No OBS: adicione uma fonte "Navegador" com o link da legenda. '
            'Nas TVs: abra o app Palco na mesma rede — ele acha o celular '
            'sozinho (ou digite IP:porta WS).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final PalcoSlot slot;
  final String? ip;
  final String? error;
  final bool busy;
  final bool canRemove;
  final String kind;
  final ValueChanged<String> onKind;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final Future<void> Function(String url) onCopy;

  const _ConnectionCard({
    required this.slot,
    required this.ip,
    required this.error,
    required this.busy,
    required this.canRemove,
    required this.kind,
    required this.onKind,
    required this.onToggle,
    required this.onRemove,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = slot.controller.isRunning;
    final clients = slot.controller.clientCount;
    final base = ip == null ? null : 'http://$ip:${slot.httpPort}';
    final isMain = slot.id == 'principal';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    TablerIcons.broadcast,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.label, style: theme.textTheme.titleMedium),
                      Text(
                        running
                            ? (clients == 0
                                  ? '● Ligada · aguardando'
                                  : '● Ligada · $clients conectado(s)')
                            : '● Desligada',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: running
                              ? Colors.greenAccent.shade400
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton.icon(
                        key: Key('transmission-toggle-${slot.id}'),
                        onPressed: onToggle,
                        icon: Icon(
                          running ? TablerIcons.square : TablerIcons.playerPlay,
                          size: 18,
                        ),
                        label: Text(running ? 'Encerrar' : 'Iniciar'),
                      ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
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
                child: Text(error!, style: theme.textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Porta ${slot.httpPort} · WebSocket ${slot.wsPort}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            if (!isMain) ...[
              Text('Tipo', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    key: Key('transmission-kind-mirror-${slot.id}'),
                    label: const Text('Espelho do Palco'),
                    selected: kind == 'mirror',
                    onSelected: (_) => onKind('mirror'),
                  ),
                  ChoiceChip(
                    key: Key('transmission-kind-return-${slot.id}'),
                    label: const Text('Retorno de palco'),
                    selected: kind == 'return',
                    onSelected: (_) => onKind('return'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                kind == 'mirror'
                    ? 'O mesmo que aparece na TV, com vídeo e áudio.'
                    : 'Para o palco: com música, mostra o trecho atual e o '
                          'próximo. Nunca toca som.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (!running || base == null)
              Text(
                'Inicie a conexão para gerar os links.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              // Principal: os três links, como no desktop; extras: o do tipo.
              if (isMain)
                _LinkRow(
                  label: 'Legenda (OBS)',
                  url: '$base/legenda',
                  onCopy: onCopy,
                ),
              if (isMain || kind == 'mirror')
                _LinkRow(
                  label: 'Espelho do Palco',
                  url: '$base/espelho',
                  onCopy: onCopy,
                ),
              if (isMain || kind == 'return')
                _LinkRow(
                  label: 'Retorno de palco',
                  url: '$base/retorno',
                  onCopy: onCopy,
                ),
            ],
            if (canRemove)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(TablerIcons.trash, size: 16),
                  label: const Text('Remover'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String url;
  final Future<void> Function(String url) onCopy;

  const _LinkRow({
    required this.label,
    required this.url,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(
          child: SelectableText(
            url,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(TablerIcons.copy, size: 18),
          tooltip: 'Copiar link',
          onPressed: () => onCopy(url),
        ),
      ],
    );
  }
}
