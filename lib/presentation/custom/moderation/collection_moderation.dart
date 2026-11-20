import 'package:flutter/material.dart';

/// Moderação de conteúdo da Comunidade (App Store 1.2): denunciar coletânea
/// e bloquear autor. Paridade com o desktop (ReportDialog da Comunidade).

/// Motivos prontos da denúncia (o texto vai para a curadoria).
const reportReasons = <String>[
  'Conteúdo ofensivo ou inadequado',
  'Não é música sacra / fora do propósito',
  'Viola direitos autorais',
  'Spam ou propaganda',
];

/// Abre o diálogo de denúncia. Volta o motivo (3–500 caracteres) ou null.
Future<String?> showReportCollectionDialog(
  BuildContext context, {
  required String collectionName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReportDialog(collectionName: collectionName),
  );
}

class _ReportDialog extends StatefulWidget {
  final String collectionName;

  const _ReportDialog({required this.collectionName});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String? get _result {
    final details = _details.text.trim();
    if (_reason == null) return null;
    final text = details.isEmpty ? _reason! : '${_reason!}: $details';
    return text.length > 500 ? text.substring(0, 500) : text;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Denunciar "${widget.collectionName}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A coletânea some da Comunidade até a curadoria revisar.',
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final reason in reportReasons)
                    RadioListTile<String>(
                      value: reason,
                      title: Text(reason),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.pop(context, _result),
          child: const Text('Denunciar'),
        ),
      ],
    );
  }
}

/// Confirma o bloqueio do autor. Volta true se confirmou.
Future<bool> showBlockAuthorDialog(
  BuildContext context, {
  required String authorName,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloquear $authorName?'),
      content: const Text(
        'As coletâneas deste autor deixam de aparecer para você na '
        'Comunidade. Você pode desbloquear depois no menu da conta, em '
        '"Usuários bloqueados".',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
