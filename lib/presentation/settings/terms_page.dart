import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Termos de Uso e Política de Privacidade — markdown estático embutido
/// (funciona offline, sem rede).
///
/// Conteúdo volta a redação própria do PIANO mobile: o app não coleta dados
/// pessoais do usuário final além de e-mail/nome usados na conta de
/// coletâneas custom (LGPD, Lei 13.709/2018).
class TermsPage extends StatelessWidget {
  /// true = Política de Privacidade; false = Termos de Uso.
  final bool isPrivacy;

  const TermsPage({super.key, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPrivacy
              ? 'settings.privacyPolicy'.tr()
              : 'settings.termsOfUse'.tr(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Icon(
              isPrivacy ? TablerIcons.shieldLock : TablerIcons.fileText,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isPrivacy ? _privacyTitle : _termsTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ..._sections(isPrivacy ? _privacySections : _termsSections, theme),
            const SizedBox(height: 16),
            Text(
              'Última atualização: 11/09/2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(List<(String, String)> sections, ThemeData theme) {
    return [
      for (final (title, body) in sections) ...[
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
      ],
    ];
  }
}

const _termsTitle = 'Termos de Uso — LouvorJA PIANO Mobile';
const _privacyTitle = 'Política de Privacidade — LouvorJA PIANO Mobile';

const _termsSections = [
  (
    '1. Aceitação',
    'Ao instalar e usar o LouvorJA PIANO Mobile, você concorda com estes '
        'Termos de Uso. Se não concorda, não utilize o aplicativo.',
  ),
  (
    '2. Uso do aplicativo',
    'O app destina-se à projeção e reprodução de hinos, letras e conteúdo '
        'de culto, para uso pessoal e em atividades religiosas. É proibido '
        'usar o app para distribuir conteúdo ilegal ou infringir direitos '
        'autorais de terceiros.',
  ),
  (
    '3. Conteúdo da comunidade',
    'Coletâneas e letras compartilhadas pela comunidade são de '
        'responsabilidade de quem as criou. O conteúdo pode ser removido a '
        'qualquer momento pelos responsáveis do serviço, em caso de '
        'violação de direitos autorais ou uso indevido.',
  ),
  (
    '4. Conta de usuário',
    'Para criar coletâneas na comunidade, é necessário criar uma conta com '
        'e-mail e senha. Você é responsável por manter suas credenciais '
        'seguras e pelo conteúdo publicado com sua conta.',
  ),
  (
    '5. Uso offline',
    'O conteúdo baixado para uso offline fica armazenado apenas no seu '
        'dispositivo e destina-se ao seu uso pessoal.',
  ),
  (
    '6. Disponibilidade',
    'O aplicativo depende de conexão com a internet para baixar conteúdo e '
        'sincronizar coletâneas da comunidade. Não garantimos '
        'disponibilidade ininterrupta do serviço.',
  ),
];

const _privacySections = [
  (
    '1. Dados que coletamos',
    'Se você cria uma conta de coletâneas da comunidade, coletamos: e-mail, '
        'nome de exibição e senha (armazenada com hash seguro, nunca em '
        'texto puro). Coletâneas e letras que você cria ficam associadas à '
        'sua conta. Se você usa o app sem criar conta, nenhum dado pessoal '
        'é coletado.',
  ),
  (
    '2. Dados armazenados no dispositivo',
    'Sua sessão de login (token) fica salva no armazenamento seguro do '
        'sistema. Downloads para uso offline (áudios e letras) ficam no '
        'armazenamento privado do app e nunca são enviados a terceiros.',
  ),
  (
    '3. Uso dos dados',
    'Os dados são usados exclusivamente para: autenticar sua conta, exibir '
        'sua autoria nas coletâneas e permitir o gerenciamento do seu '
        'conteúdo. Não vendemos, alugamos ou compartilhamos seus dados com '
        'terceiros para publicidade.',
  ),
  (
    '4. Seus direitos (LGPD — Lei 13.709/2018)',
    'Você pode solicitar a qualquer momento: acesso aos seus dados, '
        'correção, exclusão da conta e de todo o conteúdo associado, e '
        'revogação do consentimento. Para isso, entre em contato pelos '
        'canais oficiais do projeto LouvorJA.',
  ),
  (
    '5. Retenção',
    'Os dados da sua conta permanecem enquanto ela existir. Ao solicitar '
        'exclusão, a conta e o conteúdo associado são removidos em até 30 '
        'dias.',
  ),
  (
    '6. Menores de idade',
    'O app não é destinado a coleta de dados de menores de 16 anos sem '
        'consentimento dos responsáveis, conforme a LGPD.',
  ),
];
