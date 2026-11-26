library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'home_location_preferences.dart';

/// Assistente de primeira inicializacao.
///
/// Fonte: pianolouvorja/app/src/modules/onboarding/services/onboarding-preferences.ts
/// (mesma chave `onboarding.state` e mesmas regras do desktop):
/// - `full`: instalacao nova → cor de realce, animacao e, por ultimo,
///   distrito/igreja (obrigatorios);
/// - `location`: quem ja usava e esta sem distrito ou igreja → so essa etapa;
/// - `none`: nada a mostrar.
enum OnboardingMode { full, location, none }

enum OnboardingStep { accent, interaction, location }

class OnboardingState {
  /// Quando o assistente foi concluido (UTC).
  final DateTime? completedAt;

  /// Marcado na primeira abertura (SharedPreferences vazias).
  final bool freshInstall;

  /// Lembrete da Home escondido ate este momento.
  final DateTime? reminderSnoozedUntil;

  /// "Nao perguntar mais": o lembrete da Home nao volta.
  final bool reminderDismissed;

  const OnboardingState({
    this.completedAt,
    this.freshInstall = false,
    this.reminderSnoozedUntil,
    this.reminderDismissed = false,
  });

  factory OnboardingState.fromJson(Object? raw) {
    if (raw is! Map) return const OnboardingState();
    return OnboardingState(
      completedAt: _date(raw['completedAt']),
      freshInstall: raw['freshInstall'] == true,
      reminderSnoozedUntil: _date(raw['reminderSnoozedUntil']),
      reminderDismissed: raw['reminderDismissed'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'freshInstall': freshInstall,
    'reminderSnoozedUntil': reminderSnoozedUntil?.toUtc().toIso8601String(),
    'reminderDismissed': reminderDismissed,
  };

  OnboardingState copyWith({
    DateTime? reminderSnoozedUntil,
    bool? reminderDismissed,
    bool? freshInstall,
  }) => OnboardingState(
    completedAt: completedAt,
    freshInstall: freshInstall ?? this.freshInstall,
    reminderSnoozedUntil: reminderSnoozedUntil ?? this.reminderSnoozedUntil,
    reminderDismissed: reminderDismissed ?? this.reminderDismissed,
  );

  /// Concluir limpa a marca de instalacao nova.
  OnboardingState complete(DateTime now) => OnboardingState(
    completedAt: now,
    reminderSnoozedUntil: reminderSnoozedUntil,
    reminderDismissed: reminderDismissed,
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class OnboardingPreferences {
  static const storageKey = 'onboarding.state';

  /// "Lembrar depois" esconde o lembrete por 7 dias.
  static const snoozeDuration = Duration(days: 7);

  const OnboardingPreferences._();

  static Future<OnboardingState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      return raw == null
          ? const OnboardingState()
          : OnboardingState.fromJson(jsonDecode(raw));
    } catch (_) {
      return const OnboardingState();
    }
  }

  static Future<void> save(OnboardingState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Best-effort: no pior caso o assistente aparece de novo.
    }
  }

  /// Chamado no boot quando as SharedPreferences estao vazias (instalacao
  /// nova). Nao faz nada se o assistente ja foi concluido.
  static Future<void> markFreshInstall() async {
    final state = await load();
    if (state.completedAt != null || state.freshInstall) return;
    await save(state.copyWith(freshInstall: true));
  }

  static bool isLocationIncomplete(HomeLocation location) =>
      location.district.trim().isEmpty || location.church.trim().isEmpty;

  static OnboardingMode resolveMode({
    required OnboardingState state,
    required HomeLocation location,
  }) {
    if (state.completedAt != null) return OnboardingMode.none;
    if (state.freshInstall) return OnboardingMode.full;
    return isLocationIncomplete(location)
        ? OnboardingMode.location
        : OnboardingMode.none;
  }

  static List<OnboardingStep> stepsFor(OnboardingMode mode) => switch (mode) {
    OnboardingMode.full => const [
      OnboardingStep.accent,
      OnboardingStep.interaction,
      OnboardingStep.location,
    ],
    OnboardingMode.location => const [OnboardingStep.location],
    OnboardingMode.none => const [],
  };

  static bool shouldShowReminder({
    required OnboardingState state,
    required HomeLocation location,
    required DateTime now,
  }) {
    if (state.completedAt == null || state.reminderDismissed) return false;
    if (!isLocationIncomplete(location)) return false;
    final until = state.reminderSnoozedUntil;
    return until == null || !until.isAfter(now);
  }

  static DateTime snoozedUntil(DateTime now) => now.add(snoozeDuration);
}
