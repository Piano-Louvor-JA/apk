// coverage:ignore-file
// UI de controle remoto -- não testável em unit tests (Palco WS + widget tree)
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/presentation/tools/transmission_page.dart';
import 'package:louvorja_piano_mobile/presentation/tools/desktop_monitors_page.dart';
import 'package:louvorja_piano_mobile/presentation/tools/monitor_share_link.dart';

/// Painel de controle remoto: envia comandos multimídia a receivers
/// desktop/web conectados ao sender do Palco (remote.command/remote.ack).
class RemoteControlSheet extends StatefulWidget {
  const RemoteControlSheet({super.key});

  @override
  State<RemoteControlSheet> createState() => _RemoteControlSheetState();
}

class _RemoteControlSheetState extends State<RemoteControlSheet> {
  Map<String, int> _roles = const {};
  Map<String, dynamic> _playerState = const {};
  bool _sending = false;
  String _targetRole = 'desktop';

  @override
  void initState() {
    super.initState();
    _refresh();
    // Monitores do computador: atualiza o ✓ com o estado real ao abrir.
    MonitorShareSession.instance.refresh();
    MonitorShareSession.instance.loadHideIdle();
  }

  void _refresh() {
    final palco = StageSession.instance;
    if (!palco.isPalcoMode) return;
    setState(() {
      _roles = Map<String, int>.from(palco.receiverRoles);
      _playerState = Map<String, dynamic>.from(palco.remotePlayerState);
      if (_roles.containsKey(_targetRole)) return;
      // alvo desconectou: primeiro role não-TV disponível
      _targetRole =
          _roles.keys.where((r) => r != 'tv').firstOrNull ?? _targetRole;
    });
  }

  Future<void> _send(String command, {double? value}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final state = await StageSession.instance.sendRemoteCommand(
        command,
        role: _targetRole,
        value: value,
      );
      if (mounted && state != null) {
        setState(() => _playerState = state);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _playing => _playerState['playing'] == true;
  double get _volume => (_playerState['volume'] as num?)?.toDouble() ?? 0.7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palco = StageSession.instance;
    final controllable = _roles.keys.where((r) => r != 'tv').toList();

    return AnimatedBuilder(
      animation: Listenable.merge([
        StageSession.instance,
        MonitorShareSession.instance,
        // receivers mudam: reconecta o refresh
      ]),
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            const _SharedMonitorsSection(),
            const Divider(height: 32),
            _RemoteConnectionsSection(
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Controle do desktop/web',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!palco.isPalcoMode) ...[
                    Text(
                      'remote.palcoOff'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ] else if (controllable.isEmpty) ...[
                    Text(
                      'remote.noTargets'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'remote.noTargetsHint'.tr(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else ...[
                    // seletor de alvo
                    SegmentedButton<String>(
                      segments: [
                        for (final r in controllable)
                          ButtonSegment(
                            value: r,
                            // role cru ('desktop'/'web') vira chave i18n
                            label: Text('remote.$r'.tr()),
                          ),
                      ],
                      selected: {_targetRole},
                      onSelectionChanged: (s) =>
                          setState(() => _targetRole = s.first),
                    ),
                    const SizedBox(height: 16),
                    // estado do player
                    if (_playerState.isNotEmpty)
                      Text(
                        _playing ? 'remote.playing'.tr() : 'remote.paused'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // controles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filled(
                          iconSize: 32,
                          onPressed: _sending
                              ? null
                              : () => _send(_playing ? 'pause' : 'play'),
                          icon: Icon(
                            _playing
                                ? TablerIcons.playerPause
                                : TablerIcons.playerPlay,
                          ),
                        ),
                        IconButton.outlined(
                          iconSize: 28,
                          onPressed: _sending ? null : () => _send('stop'),
                          icon: const Icon(TablerIcons.playerStop),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'remote.volume'.tr(),
                      style: theme.textTheme.labelMedium,
                    ),
                    Row(
                      children: [
                        const Icon(TablerIcons.volume, size: 18),
                        Expanded(
                          child: Slider(
                            value: _volume.clamp(0.0, 1.0),
                            onChanged: _sending
                                ? null
                                : (v) => setState(
                                    () => _playerState = {
                                      ..._playerState,
                                      'volume': v,
                                    },
                                  ),
                            onChangeEnd: (v) => _send('volume', value: v),
                          ),
                        ),
                        const Icon(TablerIcons.volume2, size: 18),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Monitores compartilhados pelo app desktop: ✓ = recebe a projeção.
/// Padrão: todos marcados (o desktop já abre todos ao conectar).
class _SharedMonitorsSection extends StatefulWidget {
  const _SharedMonitorsSection();

  @override
  State<_SharedMonitorsSection> createState() => _SharedMonitorsSectionState();
}

class _SharedMonitorsSectionState extends State<_SharedMonitorsSection> {
  // Lembrado entre aberturas do painel enquanto o app está aberto.
  static bool _expanded = true;

  // Widget const: o pai reconstruir NÃO o atualiza — ele mesmo escuta o
  // estado (senão o ✓ e a opção de espera ficavam congelados na tela).
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MonitorShareSession.instance,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final session = MonitorShareSession.instance;
    final monitors = session.monitors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('shared-monitors-toggle'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                TablerIcons.devicesPc,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monitores compartilhados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (session.busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              AnimatedRotation(
                turns: _expanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  tooltip: _expanded ? 'Recolher' : 'Expandir',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: const Icon(TablerIcons.chevronUp),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (!session.connected) ...[
                      Text(
                        'Nenhum computador conectado.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use as TVs e projetores ligados por cabo ao computador como '
                        'telas do celular.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DesktopMonitorsPage(),
                          ),
                        ),
                        icon: const Icon(TablerIcons.plugConnected, size: 18),
                        label: const Text('Conectar monitor'),
                      ),
                    ] else if (monitors.isEmpty) ...[
                      Text(
                        'O computador ${session.target!.address.split(':').first} não '
                        'tem monitor escolhido para compartilhar.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else ...[
                      Text(
                        'Projetar nos marcados · ${session.target!.address.split(':').first}',
                        style: theme.textTheme.bodySmall,
                      ),
                      // Chave liga/desliga; o nome acompanha: Retirar ↔ Inserir.
                      SwitchListTile(
                        key: const Key('shared-monitors-hide-idle'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: session.hideIdle,
                        onChanged: (v) => session.setHideIdle(v),
                        // O nome diz o que a chave faz ao tocar: desligada = Retirar
                        // (liga e tira o fundo); ligada = Inserir (desliga e volta o fundo).
                        title: Text(
                          session.hideIdle
                              ? 'Inserir fundo preto de espera'
                              : 'Retirar fundo preto de espera',
                        ),
                        subtitle: Text(
                          session.hideIdle
                              ? 'Sem projeção, os monitores mostram o que já estava neles'
                              : 'Sem projeção, os monitores ficam com a tela preta de espera',
                        ),
                      ),
                      const Divider(height: 8),
                      for (final m in monitors)
                        CheckboxListTile(
                          key: Key('shared-monitor-${m.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: m.active,
                          onChanged: session.busy
                              ? null
                              : (v) async {
                                  final error = await session.toggle(
                                    m.id,
                                    v ?? false,
                                  );
                                  if (error != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error == 'not_connected'
                                              ? 'O computador desconectou. Conecte de novo.'
                                              : error,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          secondary: Icon(
                            m.mode == 'return'
                                ? TablerIcons.deviceTv
                                : TablerIcons.screenShare,
                            color: m.active
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(m.label),
                          subtitle: Text(
                            m.mode == 'return'
                                ? 'Retorno de palco'
                                : 'Espelho do palco',
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Conexões remotas = transmissões abertas em Ferramentas › Transmissão.
/// ✓ = recebe a projeção. Padrão: todas marcadas.
class _RemoteConnectionsSection extends StatefulWidget {
  const _RemoteConnectionsSection({required this.footer});

  /// Controle do desktop/web (comandos de player), dentro da seção.
  final Widget footer;

  @override
  State<_RemoteConnectionsSection> createState() =>
      _RemoteConnectionsSectionState();
}

class _RemoteConnectionsSectionState extends State<_RemoteConnectionsSection> {
  static bool _expanded = true;
  Map<String, String> _kinds = const {};

  @override
  void initState() {
    super.initState();
    PalcoOrchestrator.instance.loadStoredConfig();
    _loadKinds();
  }

  // Tipo escolhido na Transmissão ('mirror' / 'return'), mesma chave.
  Future<void> _loadKinds() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final e in prefs.getStringList('transmission_kinds') ?? const []) {
      final i = e.indexOf('=');
      if (i > 0) map[e.substring(0, i)] = e.substring(i + 1);
    }
    if (mounted) setState(() => _kinds = map);
  }

  void _openTransmission() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const TransmissionPage()));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PalcoOrchestrator.instance,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final orch = PalcoOrchestrator.instance;
    final live = orch.slots.where((s) => s.controller.isRunning).toList();
    final devices = live.fold<int>(
      0,
      (sum, s) => sum + s.controller.clientCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('remote-connections-toggle'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                TablerIcons.broadcast,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conexões remotas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  tooltip: _expanded ? 'Recolher' : 'Expandir',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: const Icon(TablerIcons.chevronUp),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (live.isEmpty) ...[
                      Text(
                        'Nenhuma transmissão no ar.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Abra conexões para TVs, navegadores e OBS na rede.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openTransmission,
                        icon: const Icon(TablerIcons.broadcast, size: 18),
                        label: const Text('Abrir Transmissão'),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Projetar nos marcados · $devices '
                              'dispositivo(s) conectado(s)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: _openTransmission,
                            child: const Text('Gerenciar'),
                          ),
                        ],
                      ),
                      // Chave liga/desliga; o nome diz o que ela faz ao tocar.
                      SwitchListTile(
                        key: const Key('remote-connections-hide-logo'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: orch.hideIdleLogo,
                        onChanged: (v) => orch.setHideIdleLogo(v),
                        title: Text(
                          orch.hideIdleLogo
                              ? 'Inserir logo na tela de espera'
                              : 'Retirar logo da tela de espera',
                        ),
                        subtitle: Text(
                          orch.hideIdleLogo
                              ? 'Sem projeção, as conexões mostram só o fundo'
                              : 'Sem projeção, as conexões mostram o logo LouvorJA',
                        ),
                      ),
                      const Divider(height: 8),
                      for (final s in live)
                        CheckboxListTile(
                          key: Key('remote-connection-${s.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: !orch.isMuted(s.id),
                          onChanged: (v) => orch.setMuted(s.id, v != true),
                          secondary: Icon(
                            _kinds[s.id] == 'return'
                                ? TablerIcons.deviceTv
                                : TablerIcons.screenShare,
                            color: orch.isMuted(s.id)
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                          ),
                          title: Text(s.label),
                          subtitle: Text(
                            [
                              s.id == 'principal'
                                  ? 'Legenda, espelho e retorno'
                                  : _kinds[s.id] == 'return'
                                  ? 'Retorno de palco'
                                  : 'Espelho do palco',
                              s.controller.clientCount > 0
                                  ? '${s.controller.clientCount} conectado(s)'
                                  : 'aguardando',
                            ].join(' · '),
                          ),
                        ),
                    ],
                    widget.footer,
                  ],
                ),
        ),
      ],
    );
  }
}
