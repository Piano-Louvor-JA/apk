library;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../../core/services/palco/palco_orchestrator.dart';

/// Seletor rapido de slot ativo (painel do cast).
///
/// - Tap num chip: vira o slot ATIVO (projeção vai só pra ele)
/// - Chip "Espelhar": envia projeção pra TODAS as TVs conectadas
/// - Chip ativo destacado (fundo primário)
class SlotSelector extends StatelessWidget {
  const SlotSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final orch = PalcoOrchestrator.instance;
    return AnimatedBuilder(
      animation: orch,
      builder: (context, _) {
        if (orch.slots.length <= 1) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                'TELA ATIVA — o conteúdo projetado vai pra ela',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final slot in orch.slots)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: slot.isConnected
                            ? Icon(
                                TablerIcons.deviceTv,
                                size: 16,
                                color:
                                    slot.id == orch.activeSlotId &&
                                        !orch.isMirrorMode
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                              )
                            : Icon(
                                TablerIcons.deviceTvOff,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                        label: Text(
                          slot.isConnected ? slot.label : 'off',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: slot.id == orch.activeSlotId
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color:
                                slot.id == orch.activeSlotId &&
                                    !orch.isMirrorMode
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                        ),
                        backgroundColor:
                            slot.id == orch.activeSlotId && !orch.isMirrorMode
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        onPressed: slot.isConnected
                            ? () => orch.setActiveSlot(slot.id)
                            : null,
                      ),
                    ),
                  // Espelho: liga/desliga envio pra todas as TVs
                  if (!orch.isMirrorMode && orch.connectedCount >= 2)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: const Icon(TablerIcons.copy, size: 16),
                        label: const Text(
                          'Espelhar',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        onPressed: () {
                          final all = orch.slots
                              .where((s) => s.isConnected)
                              .map((s) => s.id)
                              .toSet();
                          orch.toggleMirror(all);
                        },
                      ),
                    ),
                  if (orch.isMirrorMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: Icon(
                          TablerIcons.copyCheck,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          'Espelhado',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        backgroundColor: theme.colorScheme.primaryContainer,
                        onPressed: () => orch.clearMirror(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
