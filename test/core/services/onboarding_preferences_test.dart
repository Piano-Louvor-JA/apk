library;

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/home_location_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/onboarding_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Assistente de primeira inicializacao (paridade com o desktop:
/// app/src/modules/onboarding/services/onboarding-preferences.ts).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const empty = HomeLocation();
  const filled = HomeLocation(district: 'Bertioga', church: 'Rio da Praia');
  final done = OnboardingState(completedAt: DateTime.utc(2026, 11, 26));

  group('OnboardingState', () {
    test('roundtrip em SharedPreferences (mesma chave do desktop)', () async {
      final state = OnboardingState(
        completedAt: DateTime.utc(2026, 11, 26, 10),
        freshInstall: true,
        reminderSnoozedUntil: DateTime.utc(2026, 12, 3),
        reminderDismissed: true,
      );
      await OnboardingPreferences.save(state);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('onboarding.state'), isNotNull);
      final loaded = await OnboardingPreferences.load();
      expect(loaded.completedAt, state.completedAt);
      expect(loaded.freshInstall, isTrue);
      expect(loaded.reminderSnoozedUntil, state.reminderSnoozedUntil);
      expect(loaded.reminderDismissed, isTrue);
    });

    test('lixo gravado vira estado padrao', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding.state': '{"completedAt":"nao-e-data","freshInstall":"sim"}',
      });
      final loaded = await OnboardingPreferences.load();
      expect(loaded.completedAt, isNull);
      expect(loaded.freshInstall, isFalse);
      SharedPreferences.setMockInitialValues({'onboarding.state': '[1,2'});
      expect((await OnboardingPreferences.load()).completedAt, isNull);
    });
  });

  group('markFreshInstall', () {
    test('marca instalacao nova e sobrevive a reabrir', () async {
      await OnboardingPreferences.markFreshInstall();
      expect((await OnboardingPreferences.load()).freshInstall, isTrue);
    });

    test('nao marca quem ja concluiu', () async {
      await OnboardingPreferences.save(done);
      await OnboardingPreferences.markFreshInstall();
      expect((await OnboardingPreferences.load()).freshInstall, isFalse);
    });
  });

  group('resolveMode', () {
    test('instalacao nova: assistente completo, com distrito por ultimo', () {
      const state = OnboardingState(freshInstall: true);
      expect(
        OnboardingPreferences.resolveMode(state: state, location: filled),
        OnboardingMode.full,
      );
      expect(OnboardingPreferences.stepsFor(OnboardingMode.full), [
        OnboardingStep.accent,
        OnboardingStep.interaction,
        OnboardingStep.location,
      ]);
    });

    test('quem ja usava: so distrito/igreja se faltar algum', () {
      const state = OnboardingState();
      expect(
        OnboardingPreferences.resolveMode(state: state, location: empty),
        OnboardingMode.location,
      );
      expect(
        OnboardingPreferences.resolveMode(
          state: state,
          location: const HomeLocation(district: 'D'),
        ),
        OnboardingMode.location,
      );
      expect(
        OnboardingPreferences.resolveMode(state: state, location: filled),
        OnboardingMode.none,
      );
      expect(OnboardingPreferences.stepsFor(OnboardingMode.location), [
        OnboardingStep.location,
      ]);
      expect(OnboardingPreferences.stepsFor(OnboardingMode.none), isEmpty);
    });

    test('concluido nunca abre de novo', () {
      expect(
        OnboardingPreferences.resolveMode(
          state: OnboardingState(
            completedAt: DateTime.utc(2026),
            freshInstall: true,
          ),
          location: empty,
        ),
        OnboardingMode.none,
      );
    });
  });

  group('lembrete da Home', () {
    final now = DateTime.utc(2026, 11, 27, 10);

    test('so depois do assistente e enquanto faltar distrito/igreja', () {
      expect(
        OnboardingPreferences.shouldShowReminder(
          state: const OnboardingState(),
          location: empty,
          now: now,
        ),
        isFalse,
      );
      expect(
        OnboardingPreferences.shouldShowReminder(
          state: done,
          location: empty,
          now: now,
        ),
        isTrue,
      );
      expect(
        OnboardingPreferences.shouldShowReminder(
          state: done,
          location: filled,
          now: now,
        ),
        isFalse,
      );
    });

    test(
      '"Lembrar depois" esconde por 7 dias; "Nao perguntar mais" de vez',
      () {
        final snoozed = done.copyWith(
          reminderSnoozedUntil: OnboardingPreferences.snoozedUntil(now),
        );
        expect(
          OnboardingPreferences.shouldShowReminder(
            state: snoozed,
            location: empty,
            now: now,
          ),
          isFalse,
        );
        expect(
          OnboardingPreferences.shouldShowReminder(
            state: snoozed,
            location: empty,
            now: now.add(const Duration(days: 7, minutes: 1)),
          ),
          isTrue,
        );
        expect(
          OnboardingPreferences.shouldShowReminder(
            state: done.copyWith(reminderDismissed: true),
            location: empty,
            now: now,
          ),
          isFalse,
        );
      },
    );

    test('concluir limpa a marca de instalacao nova', () {
      final completed = const OnboardingState(freshInstall: true).complete(now);
      expect(completed.completedAt, now);
      expect(completed.freshInstall, isFalse);
    });
  });
}
