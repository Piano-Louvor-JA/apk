library;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../core/services/palco/palco_orchestrator.dart';
import '../../../core/services/dlna/slide_http_server.dart';

/// Sheet para gerenciar slots de palco: adicionar, remover.
class SlotManagementSheet extends StatefulWidget {
  const SlotManagementSheet({super.key});

  @override
  State<SlotManagementSheet> createState() => _SlotManagementSheetState();
}

class _SlotManagementSheetState extends State<SlotManagementSheet> {
  String? _localIp;

  @override
  void initState() {
    super.initState();
    PalcoOrchestrator.instance.addListener(_onOrchChanged);
    PalcoOrchestrator.instance.loadStoredConfig();
    _resolveIp();
  }

  @override
  void dispose() {
    PalcoOrchestrator.instance.removeListener(_onOrchChanged);
    super.dispose();
  }

  void _onOrchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _resolveIp() async {
    await SlideHttpServer.resolveLocalIp();
    if (mounted) setState(() => _localIp = SlideHttpServer.localIp);
  }

  @override
  Widget build(BuildContext context) {
    final orch = PalcoOrchestrator.instance;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gerenciar Telas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...orch.slots.map(
              (slot) => ExpansionTile(
                leading: Icon(
                  slot.isConnected
                      ? TablerIcons.deviceTv
                      : TablerIcons.deviceTvOff,
                  color: slot.isConnected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(slot.label),
                subtitle: Text(
                  slot.isConnected
                      ? 'TV ${slot.receiverIp ?? ''}  :${slot.wsPort}'
                      : 'Desconectado  :${slot.wsPort}',
                  style: theme.textTheme.bodySmall,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conectar esta tela: abra o app Palco na TV e use a '
                          'tecla VERMELHA com o IP abaixo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          '${_localIp ?? '…'}  (porta ${slot.wsPort})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (slot.id != 'principal')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'URL alternativa (navegador da TV):\n'
                              'http://${_localIp ?? '…'}:${slot.httpPort}'
                              '/receiver.html?port=${slot.wsPort}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (orch.slots.length > 1)
                          TextButton.icon(
                            icon: const Icon(TablerIcons.trash, size: 16),
                            label: const Text('Remover tela'),
                            onPressed: () async {
                              await orch.removeSlot(slot.id);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (orch.slots.length < PalcoOrchestrator.maxSlots)
              FilledButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(TablerIcons.plus, size: 18),
                label: const Text('Adicionar tela'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova tela'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome (ex: Monitor Lateral)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = c.text.trim();
              if (name.isNotEmpty) {
                final id = name.toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]'),
                  '_',
                );
                PalcoOrchestrator.instance.addSlotOnline(id: id, label: name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}
