library;

import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_accents.dart';
import '../../core/constants/app_version.dart';
import '../../core/services/settings_controller.dart';
import '../../core/services/sync/sync_file_service.dart';
import '../../core/services/update_service.dart';
import 'widgets/remote/remote_section.dart';
import 'widgets/stage_section.dart';
import 'widgets/sync_section.dart';

/// SettingsPage — tela de configuracoes (tab "Mais").
///
/// Fonte: pianolouvorja/app/src/modules/settings/views/AppearanceView.vue
/// + GeneralView.vue
///
/// Secoes (adaptadas do Electron, sem projecao/media):
/// 1. Aparencia: tema, cor de acento, perfil de interacao, intensidade glass
/// 2. Geral: idioma, versao do app
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checkingUpdate = false;
  String? _updateStatus;
  bool _isClearing = false;
  bool _syncBusy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final locale =
        EasyLocalization.of(context)?.locale ?? Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Aparencia ---
            _SectionHeader(
              icon: TablerIcons.palette,
              title: 'settings.appearance'.tr(),
            ),
            const SizedBox(height: 12),

            // Tema — controle orbital: claro ↔ sistema ↔ escuro.
            _SettingsCard(
              icon: TablerIcons.sunMoon,
              title: 'settings.theme'.tr(),
              child: _ThemeOrbitalControl(
                mode: settings.themeMode,
                onChanged: settings.setThemeMode,
              ),
            ),
            const SizedBox(height: 12),

            // Cor de acento
            _SettingsCard(
              icon: TablerIcons.colorSwatch,
              title: 'settings.accentColor'.tr(),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AccentKey.values.map((key) {
                  final accent = AppAccents.byId(key.name);
                  final isSelected = settings.accent == key;
                  return GestureDetector(
                    key: Key('accent-${key.name}'),
                    onTap: () => settings.setAccent(key),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.primary,
                        shape: BoxShape.circle,
                        border: isSelected
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
            ),
            const SizedBox(height: 12),

            // Perfil de interacao
            _SettingsCard(
              icon: TablerIcons.keyframes,
              title: 'settings.animationProfile'.tr(),
              child: Wrap(
                spacing: 8,
                children: InteractionKey.values.map((key) {
                  final labels = {
                    InteractionKey.dynamic_: 'settings.interactionDynamic'.tr(),
                    InteractionKey.soft: 'settings.interactionSoft'.tr(),
                    InteractionKey.mist: 'settings.interactionMist'.tr(),
                  };
                  return _ChoiceChip<InteractionKey>(
                    key: Key('interaction-${key.name}'),
                    label: labels[key]!,
                    selected: settings.interaction == key,
                    onTap: () => settings.setInteraction(key),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Intensidade do glass
            _SettingsCard(
              icon: TablerIcons.blur,
              title: 'settings.glassIntensity'.tr(),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      key: const Key('glass-intensity'),
                      value: settings.glassIntensity.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${settings.glassIntensity}%',
                      onChanged: (v) => settings.setGlassIntensity(v.round()),
                    ),
                  ),
                  Text('${settings.glassIntensity}%'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- Palco (cast) — RF-01/02 spec palco-v2 ---
            _SectionHeader(icon: TablerIcons.cast, title: 'Palco'),
            const SizedBox(height: 12),
            const StageSection(),
            const SizedBox(height: 32),

            // --- Geral ---
            _SectionHeader(
              icon: TablerIcons.adjustments,
              title: 'settings.sectionGeneral'.tr(),
            ),
            const SizedBox(height: 12),

            // Idioma
            _SettingsCard(
              icon: TablerIcons.language,
              title: 'settings.language'.tr(),
              child: Wrap(
                spacing: 8,
                children: [
                  _ChoiceChip(
                    label: 'settings.languagePortuguese'.tr(),
                    selected: locale == const Locale('pt', 'BR'),
                    onTap: () => EasyLocalization.of(
                      context,
                      // coverage:ignore-line
                    )?.setLocale(const Locale('pt', 'BR')),
                  ),
                  _ChoiceChip(
                    label: 'settings.languageEnglish'.tr(),
                    selected: locale == const Locale('en'),
                    // API nao possui catalogo em ingles (apenas PT e ES).
                    enabled: false,
                    onTap: null,
                  ),
                  _ChoiceChip(
                    label: 'settings.languageSpanish'.tr(),
                    selected: locale == const Locale('es'),
                    // coverage:ignore-line
                    onTap: () => EasyLocalization.of(
                      context,
                      // coverage:ignore-line
                    )?.setLocale(const Locale('es')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Versao
            FutureBuilder<String>(
              future: AppVersion.displayVersion,
              builder: (context, snapshot) {
                return _SettingsCard(
                  icon: TablerIcons.infoCircle,
                  title: 'settings.version'.tr(),
                  child: Text(
                    snapshot.data ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Verificar atualizacoes (manual)
            _SettingsCard(
              icon: TablerIcons.refreshDot,
              title: 'Atualizações',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verifique se há uma nova versão disponível.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _checkingUpdate ? null : _handleCheckUpdate,
                    icon: Icon(
                      _checkingUpdate
                          ? TablerIcons.loader2
                          : TablerIcons.cloudDownload,
                    ),
                    label: Text(
                      _checkingUpdate
                          ? 'Verificando...'
                          : 'Verificar atualização',
                    ),
                  ),
                  if (_updateStatus != null) ...[
                    const SizedBox(height: 8),
                    // coverage:ignore-line
                    Text(
                      // coverage:ignore-line
                      _updateStatus!,
                      // coverage:ignore-line
                      style: theme.textTheme.bodySmall?.copyWith(
                        // coverage:ignore-line
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Limpar dados (reset de fabrica)
            _SettingsCard(
              icon: TablerIcons.database,
              title: 'Dados locais',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remove todos os dados do app: cache, configurações, '
                    'liturgia salva e músicas baixadas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _isClearing ? null : _handleClearData,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                    ),
                    icon: Icon(
                      _isClearing ? TablerIcons.loader2 : TablerIcons.trash,
                    ),
                    label: Text(
                      _isClearing ? 'Limpando...' : 'Apagar todos os dados',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Sincronizacao (pacote .louvorja) ---
            SyncSection(
              busy: _syncBusy,
              onExport: _handleSyncExport,
              onImport: _handleSyncImport,
            ),
            const SizedBox(height: 24),

            // --- Controle remoto (APK → Desktop/Web) ---
            const RemoteSection(),
            const SizedBox(height: 24),

            // Termos e Privacidade (link)
            ListTile(
              leading: Icon(
                TablerIcons.shieldCheck,
                color: theme.colorScheme.primary,
              ),
              title: Text('settings.termsOfUse'.tr()),
              trailing: const Icon(TablerIcons.chevronRight),
              onTap: () => context.push('/settings/terms'),
            ),
            ListTile(
              leading: Icon(
                TablerIcons.shieldLock,
                color: theme.colorScheme.primary,
              ),
              title: Text('settings.privacyPolicy'.tr()),
              trailing: const Icon(TablerIcons.chevronRight),
              onTap: () => context.push('/settings/privacy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSyncExport() async {
    setState(() => _syncBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await SyncFileService().export();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            path != null ? 'sync.exported'.tr() : 'sync.exportCancelled'.tr(),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Falha ao exportar.')),
      );
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Future<void> _handleSyncImport() async {
    setState(() => _syncBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await SyncFileService().import();
      if (!mounted) return;
      if (r == null) {
        messenger.showSnackBar(
          SnackBar(content: Text('sync.importInvalid'.tr())),
        );
      } else if (r.applied.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('sync.importedNone'.tr())),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'sync.imported'.tr(namedArgs: {'applied': r.applied.join(', ')}),
            ),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Falha ao importar.')),
      );
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  // coverage:ignore-start
  Future<void> _handleCheckUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = null;
    });
    try {
      final service = UpdateService();
      final result = await service.checkForUpdates();
      if (!mounted) return;
      if (result.hasUpdate && result.downloadUrl != null) {
        if (kIsWeb) {
          // coverage:ignore-line
          setState(() {
            _updateStatus = 'Versão ${result.latestVersion} disponível!';
          });
          await launchUrl(
            Uri.parse(result.downloadUrl!),
            webOnlyWindowName: '_blank',
          );
        } else {
          setState(() {
            _updateStatus =
                'Versão ${result.latestVersion} disponível. Baixando...';
          });
          final path = await service.downloadApk(
            result.downloadUrl!,
            expectedSha256: result.apkSha256,
          );
          await OpenFilex.open(path);
        }
      } else if (result.isUnavailable) {
        // A consulta FALHOU (404 repo privado sem token, rede etc.) —
        // dizer "voce esta atualizado" aqui seria mentira.
        setState(() {
          _updateStatus = switch (result.failure) {
            UpdateCheckFailure.unauthorized =>
              'Não foi possível verificar: repositório privado. Aguarde '
                  'uma decisão de acesso (repo público ou proxy).',
            _ =>
              'Não foi possível verificar atualizações. Verifique sua '
                  'conexão e tente novamente.',
          };
        });
      } else {
        setState(() {
          _updateStatus = 'Você já está usando a versão mais recente.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _updateStatus = 'Não foi possível verificar atualizações.';
        });
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _handleClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar todos os dados?'),
        content: const Text(
          'Isso vai remover cache, configurações, liturgia salva e '
          'músicas baixadas. O app vai reiniciar. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados apagados. Reinicie o app.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  // coverage:ignore-end
}

/// Equivalente Flutter do `theme-orbital__control` do web.
///
/// O trilho tem três pontos discretos: 0=claro, 50=sistema e 100=escuro.
class _ThemeOrbitalControl extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeOrbitalControl({required this.mode, required this.onChanged});

  double get _value => switch (mode) {
    ThemeMode.light => 0,
    ThemeMode.system => 50,
    ThemeMode.dark => 100,
  };

  String get _ariaText => switch (mode) {
    ThemeMode.light => 'settings.themeLight'.tr(),
    ThemeMode.system => 'settings.themeSystem'.tr(),
    ThemeMode.dark => 'settings.themeDark'.tr(),
  };

  ThemeMode _modeFromValue(double value) {
    if (value < 25) return ThemeMode.light;
    if (value > 75) return ThemeMode.dark;
    return ThemeMode.system;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = mode == ThemeMode.light;
    final isDark = mode == ThemeMode.dark;

    return Semantics(
      label: 'settings.theme'.tr(),
      value: _ariaText,
      child: Row(
        children: [
          _ThemeModeButton(
            key: const Key('theme-light'),
            icon: TablerIcons.sun,
            tooltip: 'settings.themeLight'.tr(),
            active: isLight,
            onPressed: () => onChanged(ThemeMode.light),
          ),
          Expanded(
            child: Semantics(
              label: 'settings.themeSystem'.tr(),
              value: _ariaText,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.24),
                  thumbColor: theme.colorScheme.primary,
                ),
                child: Slider(
                  key: const Key('theme-orbital-slider'),
                  value: _value,
                  min: 0,
                  max: 100,
                  divisions: 2,
                  label: _ariaText,
                  onChanged: (value) => onChanged(_modeFromValue(value)),
                ),
              ),
            ),
          ),
          _ThemeModeButton(
            key: const Key('theme-dark'),
            icon: TablerIcons.moon,
            tooltip: 'settings.themeDark'.tr(),
            active: isDark,
            onPressed: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  const _ThemeModeButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        color: active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        style: IconButton.styleFrom(
          backgroundColor: active
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip<T> extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: enabled ? (_) => onTap?.call() : null,
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}
