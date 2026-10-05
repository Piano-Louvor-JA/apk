library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/terms_acceptance_sheet.dart';

/// Gate de aceitação de Termos de Uso / Política de Privacidade no
/// fluxo QR → conectar (apk#95): os termos devem ser aceitáveis e
/// dispensáveis ANTES do conectar, sem sobreposição que bloqueie o botão.
///
/// A aceitação fica em SharedPreferences (`terms_accepted_at`) e vale
/// por versão dos termos (`terms_version`).
class TermsAcceptance {
  TermsAcceptance._();

  static const acceptedAtKey = 'terms_accepted_at';
  static const versionKey = 'terms_version';

  /// Bump quando o conteúdo dos termos mudar de forma relevante.
  static const currentVersion = '1';

  static final TermsAcceptance instance = TermsAcceptance._();

  Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(acceptedAtKey) != null &&
        prefs.getString(versionKey) == currentVersion;
  }

  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(acceptedAtKey, DateTime.now().toIso8601String());
    await prefs.setString(versionKey, currentVersion);
  }
}

/// Garante termos aceitos antes de prosseguir (ex: conectar via QR).
/// Retorna true se já aceitos ou aceitos agora; false se o usuário
/// dispensou (fluxo segue dispensável — nada bloqueia além do sheet).
Future<bool> ensureTermsAccepted(BuildContext context) async {
  if (await TermsAcceptance.instance.isAccepted()) return true;
  if (!context.mounted) return false;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Tela baixa: constraint + scroll — botões nunca cortados/overlap.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => const TermsAcceptanceSheet(),
  );
  return accepted ?? false;
}
