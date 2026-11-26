library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../app/theme/app_accents.dart';
import '../../core/services/home_location_preferences.dart';
import '../../core/services/onboarding_preferences.dart';
import '../../core/services/settings_controller.dart';

/// Assistente de primeira inicializacao (paridade com o desktop:
/// app/src/modules/onboarding/components/OnboardingDialog.vue).
///
/// - Instalacao nova: cor de realce → animacao → distrito/igreja (obrigatorios).
///   Cartao "Seja bem-vindo" em todas as etapas, logo pulsando.
/// - Atualizacao sem distrito/igreja: so a etapa de distrito/igreja, com
///   titulo "Atualizacao do Piano LouvorJA".
/// - Cor e animacao tem "Usar padrao" (padroes do APK: laranja, dinamico).
///
/// [onSaveLocation] grava distrito/igreja (com outbox do sync na Home).
class OnboardingDialog extends StatefulWidget {
  final OnboardingMode mode;
  final HomeLocation initialLocation;
  final Future<void> Function(HomeLocation location) onSaveLocation;

  const OnboardingDialog({
    super.key,
    required this.mode,
    required this.initialLocation,
    required this.onSaveLocation,
  });

  /// Abre em tela cheia, sem fechar tocando fora nem pelo botao voltar.
  static Future<void> show(
    BuildContext context, {
    required OnboardingMode mode,
    required HomeLocation initialLocation,
    required Future<void> Function(HomeLocation location) onSaveLocation,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: OnboardingDialog(
          mode: mode,
          initialLocation: initialLocation,
          onSaveLocation: onSaveLocation,
        ),
      ),
    );
  }

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog>
    with SingleTickerProviderStateMixin {
  late final List<OnboardingStep> _steps;
  int _index = 0;
  bool _saving = false;
  late final TextEditingController _district;
  late final TextEditingController _church;
  late final AnimationController _pulse;

  bool get _isUpdate => widget.mode == OnboardingMode.location;
  OnboardingStep get _step => _steps[_index];
  bool get _isLast => _index == _steps.length - 1;
  bool get _locationFilled =>
      _district.text.trim().isNotEmpty && _church.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _steps = OnboardingPreferences.stepsFor(widget.mode);
    _district = TextEditingController(text: widget.initialLocation.district)
      ..addListener(_refresh);
    _church = TextEditingController(text: widget.initialLocation.church)
      ..addListener(_refresh);
    // Mesma pulsacao suave do logo da Home (escala ate 4%, ciclo de 3,2 s).
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _district.dispose();
    _church.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == OnboardingStep.location && !_locationFilled) return;
    if (!_isLast) {
      setState(() => _index++);
      return;
    }
    setState(() => _saving = true);
    await widget.onSaveLocation(
      HomeLocation(
        district: _district.text.trim(),
        church: _church.text.trim(),
      ),
    );
    final state = await OnboardingPreferences.load();
    await OnboardingPreferences.save(state.complete(DateTime.now().toUtc()));
    if (mounted) Navigator.of(context).pop();
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  void _useDefault(SettingsController settings) {
    if (_step == OnboardingStep.accent) {
      settings.setAccent(AccentKey.orange);
    } else if (_step == OnboardingStep.interaction) {
      settings.setInteraction(InteractionKey.dynamic_);
    }
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Cor e animacao usam o controller; a etapa de distrito/igreja nao
    // depende dele (Home de atualizacao sem Provider continua funcionando).
    final settings = _step == OnboardingStep.location
        ? null
        : context.watch<SettingsController>();
    final primary = theme.colorScheme.primary;

    return Dialog(
      key: const Key('onboarding-dialog'),
      insetPadding: const EdgeInsets.all(16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _isUpdate ? TablerIcons.refresh : TablerIcons.sparkles,
                    size: 16,
                    color: primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (_isUpdate
                              ? 'onboarding.update.wizardTitle'
                              : 'onboarding.wizardTitle')
                          .tr()
                          .toUpperCase(),
                      key: const Key('onboarding-wizard-title'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (_steps.length > 1)
                    Text(
                      'onboarding.stepOf'.tr(
                        namedArgs: {
                          'current': '${_index + 1}',
                          'total': '${_steps.length}',
                        },
                      ),
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
              if (_steps.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  children: List.generate(_steps.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active || i < _index
                            ? primary.withValues(alpha: active ? 1 : 0.55)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.2,
                              ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 12),
              _WelcomeCard(isUpdate: _isUpdate, pulse: _pulse),
              const SizedBox(height: 16),
              ..._stepBody(theme, settings),
              const SizedBox(height: 16),
              // Wrap: em tela estreita os botoes quebram de linha em vez de
              // estourar a largura.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_index > 0)
                    TextButton(
                      key: const Key('onboarding-back'),
                      onPressed: _saving ? null : _back,
                      child: Text('onboarding.back'.tr()),
                    ),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_step != OnboardingStep.location)
                          OutlinedButton(
                            key: const Key('onboarding-default'),
                            onPressed: () => _useDefault(settings!),
                            child: Text('onboarding.useDefault'.tr()),
                          ),
                        FilledButton(
                          key: const Key('onboarding-primary'),
                          onPressed:
                              _saving ||
                                  (_step == OnboardingStep.location &&
                                      !_locationFilled)
                              ? null
                              : _next,
                          child: Text(
                            _isUpdate
                                ? 'onboarding.save'.tr()
                                : (_isLast
                                      ? 'onboarding.finish'.tr()
                                      : 'onboarding.continue'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepBody(ThemeData theme, SettingsController? settings) {
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    switch (_step) {
      case OnboardingStep.accent:
        return [
          Text('onboarding.accent.title'.tr(), style: titleStyle),
          const SizedBox(height: 6),
          Text('onboarding.accent.text'.tr(), style: textStyle),
          const SizedBox(height: 14),
          Wrap(
            key: const Key('onboarding-step-accent'),
            spacing: 12,
            runSpacing: 12,
            children: AccentKey.values.map((key) {
              final accent = AppAccents.byId(key.name);
              final selected = settings!.accent == key;
              return GestureDetector(
                key: Key('onboarding-accent-${key.name}'),
                onTap: () => settings.setAccent(key),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.primary,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ];
      case OnboardingStep.interaction:
        final labels = {
          InteractionKey.dynamic_: 'settings.interactionDynamic'.tr(),
          InteractionKey.soft: 'settings.interactionSoft'.tr(),
          InteractionKey.mist: 'settings.interactionMist'.tr(),
        };
        return [
          Text('onboarding.interaction.title'.tr(), style: titleStyle),
          const SizedBox(height: 6),
          Text('onboarding.interaction.text'.tr(), style: textStyle),
          const SizedBox(height: 14),
          Wrap(
            key: const Key('onboarding-step-interaction'),
            spacing: 8,
            runSpacing: 8,
            children: InteractionKey.values.map((key) {
              return ChoiceChip(
                key: Key('onboarding-interaction-${key.name}'),
                label: Text(labels[key]!),
                selected: settings!.interaction == key,
                onSelected: (_) => settings.setInteraction(key),
              );
            }).toList(),
          ),
        ];
      case OnboardingStep.location:
        return [
          Icon(
            TablerIcons.buildingChurch,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text('onboarding.location.title'.tr(), style: titleStyle),
          const SizedBox(height: 6),
          Text('onboarding.location.text'.tr(), style: textStyle),
          const SizedBox(height: 14),
          TextField(
            key: const Key('onboarding-district'),
            controller: _district,
            maxLength: 80,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'onboarding.location.district'.tr(),
              hintText: 'home.districtPlaceholder'.tr(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('onboarding-church'),
            controller: _church,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            decoration: InputDecoration(
              labelText: 'onboarding.location.church'.tr(),
              hintText: 'home.churchPlaceholder'.tr(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                TablerIcons.lock,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'onboarding.location.privacy'.tr(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (!_locationFilled) ...[
            const SizedBox(height: 6),
            Row(
              key: const Key('onboarding-required'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  TablerIcons.infoCircle,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'onboarding.location.required'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ];
    }
  }
}

class _WelcomeCard extends StatelessWidget {
  final bool isUpdate;
  final Animation<double> pulse;

  const _WelcomeCard({required this.isUpdate, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      key: const Key('onboarding-welcome'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          colors: [primary.withValues(alpha: 0.16), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween<double>(
              begin: 1,
              end: 1.04,
            ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
            child: SvgPicture.asset(
              'assets/images/logo-louvor-ja.svg',
              width: 52,
              height: 52,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (isUpdate
                          ? 'onboarding.update.title'
                          : 'onboarding.welcome.title')
                      .tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (isUpdate
                          ? 'onboarding.update.text'
                          : 'onboarding.welcome.text')
                      .tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
