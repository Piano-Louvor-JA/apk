library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// F3.3t: o receiver Palco na TV é CLIENTE WebSocket — não escuta porta
/// nenhuma, logo um scan de rede nunca vai encontrá-lo. O fluxo correto é
/// invertido: o CELULAR sobe o sender (HTTP :7080 + WS :7081) e mostra o
/// IP dele; a TV (app Palco instalado) conecta nesse IP.
///
/// Este dialog substitui o antigo scan enganoso (:7080/status na sub-rede,
/// que achava outros celulares — nunca a TV) por:
///  1. IP do celular em destaque + botão copiar (pra digitar/QR na TV)
///  2. Campo de confirmação simples (o IP da TV não é mais necessário
///     para conectar — o sender aceita qualquer receiver que conecte).
///
/// Retorna true se o usuário confirmou (sender ligado), null se cancelou.
class PalcoConnectDialog extends StatefulWidget {
  final String mobileIp;

  const PalcoConnectDialog({super.key, required this.mobileIp});

  @override
  State<PalcoConnectDialog> createState() => _PalcoConnectDialogState();
}

class _PalcoConnectDialogState extends State<PalcoConnectDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Palco LouvorJA'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Abra o app Palco na TV e digite este IP:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.mobileIp,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: widget.mobileIp),
                    );
                    if (mounted) {
                      setState(() => _copied = true);
                      Future.delayed(
                        const Duration(seconds: 2),
                        () => mounted ? setState(() => _copied = false) : null,
                      );
                    }
                  },
                  icon: Icon(_copied ? Icons.check : Icons.copy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'O receiver da TV conecta sozinho neste celular assim que o IP '
            'for informado. O sender fica ativo aguardando a conexão.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ligar sender'),
        ),
      ],
    );
  }
}
