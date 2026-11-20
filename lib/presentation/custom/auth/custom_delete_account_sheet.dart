import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';

/// Bottom sheet de exclusão de conta (App Store 5.1.1(v) / LGPD).
///
/// Paridade com o desktop (AuthAccountDialog): aviso do que é apagado,
/// senha atual para confirmar e botão destrutivo. Volta true se excluiu.
class CustomDeleteAccountSheet extends StatefulWidget {
  final CustomAuthController controller;

  const CustomDeleteAccountSheet({super.key, required this.controller});

  static Future<bool> show(
    BuildContext context,
    CustomAuthController controller,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: CustomDeleteAccountSheet(controller: controller),
      ),
    ).then((deleted) {
      if (deleted == true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Conta excluída.')),
        );
      }
      return deleted ?? false;
    });
  }

  @override
  State<CustomDeleteAccountSheet> createState() =>
      _CustomDeleteAccountSheetState();
}

class _CustomDeleteAccountSheetState extends State<CustomDeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await widget.controller.deleteAccount(_password.text);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = _errorMessage(widget.controller.errorCode);
    });
  }

  String _errorMessage(String? code) {
    switch (code) {
      case 'errors.wrongPassword':
        return 'Senha incorreta.';
      case 'errors.passwordRequired':
        return 'Digite sua senha para confirmar.';
      case 'errors.sessionExpired':
        return 'Sessão expirada. Entre de novo para excluir a conta.';
      case 'errors.connection':
        return 'Sem conexão com o servidor. Tente novamente.';
      default:
        return 'Não foi possível excluir a conta. Tente novamente.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Excluir sua conta',
                style: theme.textTheme.titleLarge?.copyWith(color: danger),
              ),
              const SizedBox(height: 12),
              Text(
                'Isso apaga sua conta, suas coletâneas privadas, pontos e '
                'notificações. As coletâneas públicas continuam na '
                'Comunidade, sem o seu nome. Não dá para desfazer.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  helperText: 'Digite sua senha para confirmar.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Informe a senha' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: danger)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Excluir definitivamente'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
