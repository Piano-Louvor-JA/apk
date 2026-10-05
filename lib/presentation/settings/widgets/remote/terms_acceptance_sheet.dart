library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/core/services/terms_acceptance.dart';

/// Bottom sheet de aceitação de Termos de Uso / Política de Privacidade.
///
/// Conteúdo resumido + links completos (rotas /settings/terms e
/// /settings/privacy). Scrollável: em tela pequena os botões ficam
/// acessíveis (nada sobrepõe o botão de conectar — apk#95).
class TermsAcceptanceSheet extends StatelessWidget {
  const TermsAcceptanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    TablerIcons.shieldCheck,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'settings.termsOfUse'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Para usar o controle por QR, leia e aceite os Termos de Uso '
                'e a Política de Privacidade. O app não coleta dados '
                'pessoais além do que está descrito na política.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => context.push('/settings/terms'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'settings.termsOfUse'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const Text('  ·  '),
                  InkWell(
                    onTap: () => context.push('/settings/privacy'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'settings.privacyPolicy'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('terms-accept'),
                onPressed: () async {
                  await TermsAcceptance.instance.accept();
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                child: const Text('Aceitar e continuar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('terms-dismiss'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
