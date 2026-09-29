import 'package:flutter/material.dart';

import 'package:louvorja_piano_mobile/presentation/custom/auth/custom_auth_controller.dart';

/// Bottom sheet de login/registro da conta custom.
///
/// Uma tela só: formulário login com link "criar conta" que troca o modo.
/// Retorna via [CustomAuthController] — não navega.
class CustomAuthSheet extends StatefulWidget {
  final CustomAuthController controller;

  const CustomAuthSheet({super.key, required this.controller});

  /// Abre o sheet; volta true se autenticou.
  static Future<bool> show(
    BuildContext context,
    CustomAuthController controller,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CustomAuthSheet(controller: controller),
      ),
    ).then((v) => v ?? false);
  }

  @override
  State<CustomAuthSheet> createState() => _CustomAuthSheetState();
}

class _CustomAuthSheetState extends State<CustomAuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final ok = _isRegister
        ? await widget.controller.register(
            _email.text.trim(),
            _password.text,
            _displayName.text.trim(),
          )
        : await widget.controller.login(_email.text.trim(), _password.text);

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorMessage(widget.controller.errorCode))),
    );
  }

  String _errorMessage(String? code) {
    switch (code) {
      case 'errors.invalidCredentials':
        return 'E-mail ou senha inválidos.';
      case 'errors.emailInUse':
        return 'Este e-mail já está cadastrado.';
      case 'errors.connection':
        return 'Sem conexão com o servidor. Tente novamente.';
      default:
        return 'Não foi possível entrar. Tente novamente.';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _isRegister ? 'Criar conta' : 'Entrar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_isRegister) ...[
                TextFormField(
                  controller: _displayName,
                  decoration: const InputDecoration(
                    labelText: 'Seu nome',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  helperText: _isRegister ? 'Mínimo de 8 caracteres' : null,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe a senha';
                  if (_isRegister && v.length < 8) {
                    return 'Mínimo de 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegister ? 'Criar conta' : 'Entrar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _isRegister = !_isRegister),
                child: Text(
                  _isRegister
                      ? 'Já tenho conta — entrar'
                      : 'Não tenho conta — criar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
