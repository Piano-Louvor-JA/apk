library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme/app_spacing.dart';
import '../../core/services/apk_installer.dart';
import '../../core/services/apk_version_guard.dart';
import '../../core/services/update_service.dart';
import '../shared/widgets/gradient_background.dart';
import '../shared/widgets/update_banner.dart';

/// HomePage — tela inicial identica ao app desktop.
///
/// Fonte: pianolouvorja/app/src/modules/home/views/HomeView.vue
///
/// Layout centralizado:
/// - Logo LouvorJA (128px)
/// - Campo editavel: Distrito (lg)
/// - Campo editavel: Igreja (md)
/// - Relogio digital em tempo real (32px, cor primary, glow)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _now;
  Timer? _clockTimer;
  final _districtController = TextEditingController();
  final _churchController = TextEditingController();
  bool _editingDistrict = true;
  bool _editingChurch = false;

  // Auto-update
  late final UpdateService _updateService;
  UpdateCheckResult? _update;
  bool _checkingUpdate = false;
  bool _downloading = false;
  int? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _updateService = UpdateService();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _checkForUpdates();
  }

  // coverage:ignore-start
  Future<void> _checkForUpdates() async {
    // Widget tests/debug nao devem abrir requisicao real nem timer Dio.
    // O auto-update permanece ativo em APK/Web release.
    if (!kReleaseMode || _checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final result = await _updateService.checkForUpdates();
      if (mounted) setState(() => _update = result);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<PackageInfo> _packageInfo() => // coverage:ignore-line
      PackageInfo.fromPlatform();

  Future<void> _performUpdate() async {
    final update = _update;
    if (update == null || update.downloadUrl == null) return;

    // Guard: APK alvo precisa AVANÇAR a versão instalada. Bloqueia o
    // loop release-quebrada (v0.1.16 com APK 0.1.15 interno, 2026-08-16).
    final guard = ApkVersionGuard.canInstall(
      installed: (await _packageInfo()).version,
      available: update.latestVersion ?? '',
    );
    if (!guard.allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              guard.reason == ApkVersionRejectReason.sameVersion
                  ? 'A atualização disponível é a mesma versão instalada.'
                  : 'A atualização disponível é mais antiga que a instalada.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });

    try {
      final path = await _updateService.downloadApk(
        update.downloadUrl!,
        expectedSha256: update.apkSha256,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _downloadProgress = (received * 100 ~/ total));
          }
        },
      );
      // PackageInstaller.Session (nativo): imune ao congelamento do app
      // no OneUI. needs_permission abre Settings p/ fonte desconhecida;
      // failed cai no fallback legado (OpenFilex).
      final outcome = await ApkInstaller.install(path);
      if (outcome == ApkInstallOutcome.failed) {
        await OpenFilex.open(path);
      } else if (outcome == ApkInstallOutcome.needsPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permita instalar apps desconhecidos para o Piano LouvorJA '
                'e toque em Atualizar novamente.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível baixar a atualização.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
    // coverage:ignore-end
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _updateService.dispose();
    _districtController.dispose();
    _churchController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            // coverage:ignore-start
            // Banner de atualizacao
            if (_update != null && _update!.hasUpdate)
              UpdateBanner(
                version: _update!.latestVersion ?? '',
                apkSizeBytes: _update!.apkSize,
                releaseNotes: _update!.releaseNotes,
                downloadUrl: _update!.downloadUrl,
                onUpdate: _performUpdate,
                onDismiss: () =>
                    setState(() => _update = UpdateCheckResult.none),
              ),
            if (_downloading)
              LinearProgressIndicator(
                value: _downloadProgress != null
                    ? _downloadProgress! / 100
                    : null,
              ),
            // coverage:ignore-end
            // Conteudo principal
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.pageMargin),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo LouvorJA 128px centralizado
                      SvgPicture.asset(
                        'assets/images/logo-louvor-ja.svg',
                        width: 128,
                        height: 128,
                      ),
                      const SizedBox(height: 40),

                      // Distrito (editavel, size lg)
                      _LocationField(
                        label: 'home.districtLabel'.tr(),
                        fontSize: 24,
                        controller: _districtController,
                        editing: _editingDistrict,
                        onEdit: () => setState(() => _editingDistrict = true),
                        onSubmit: (value) => setState(() {
                          _districtController.text = value;
                          _editingDistrict = false;
                          _editingChurch = _churchController.text.isEmpty;
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Igreja (editavel, size md)
                      _LocationField(
                        label: 'home.churchLabel'.tr(),
                        fontSize: 18,
                        controller: _churchController,
                        editing: _editingChurch,
                        onEdit: () => setState(() => _editingChurch = true),
                        onSubmit: (value) => setState(() {
                          _churchController.text = value;
                          _editingChurch = false;
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Relogio digital em tempo real
                      Text(
                        _formattedTime,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: theme.colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ), // Expanded
          ], // Column children
        ), // Column
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final String label;
  final double fontSize;
  final TextEditingController controller;
  final bool editing;
  final VoidCallback onEdit;
  final ValueChanged<String> onSubmit;

  const _LocationField({
    required this.label,
    required this.fontSize,
    required this.controller,
    required this.editing,
    required this.onEdit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = controller.text.trim().isNotEmpty;

    if (editing) {
      return SizedBox(
        width: 320,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          autofocus: true,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
          onSubmitted: onSubmit,
        ),
      );
    }

    return GestureDetector(
      onTap: onEdit,
      child: Text(
        filled ? controller.text : label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
          color: filled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
