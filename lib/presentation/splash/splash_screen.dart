library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_version.dart';
import '../shared/widgets/codename_piano.dart';
import '../shared/widgets/louvorja_logo.dart';

/// Tela de splash — mostra logo + codinome PIANO durante boot.
///
/// Fonte: pianolouvorja/app/src/modules/starting/
/// Overlay visivel durante inicializacao com logo + codinome + status.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onInitializationComplete;
  final Future<String>? versionFuture;

  const SplashScreen({
    super.key,
    this.onInitializationComplete,
    this.versionFuture,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeLogo;
  Animation<double>? _fadeCodename;
  Animation<double>? _fadeStatus;
  Timer? _bootTimer;
  bool _completed = false;
  String _version = '';

  void _completeInitialization() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onInitializationComplete?.call();
  }

  @override
  void initState() {
    super.initState();

    // Versao real do PackageInfo; sem fallback hardcoded (bug: timeout
    // de 1.5s no cold start release travava a splash em 'v0.1.0' para
    // sempre). Boot comeca apos 400ms; quando a versao chegar, o texto
    // atualiza via setState — nunca exibir versao falsa.
    (widget.versionFuture ?? AppVersion.displayVersion)
        .then((v) {
          if (!mounted) return;
          setState(() => _version = v);
        })
        .catchError((_) {});
    Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _startBootSequence();
    });
  }

  void _startBootSequence() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeLogo = CurvedAnimation(
      parent: _controller!,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _fadeCodename = CurvedAnimation(
      parent: _controller!,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );
    _fadeStatus = CurvedAnimation(
      parent: _controller!,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _controller!.forward();

    // CRITICO: reconstruir a arvore agora. Sem este setState o rebuild
    // so acontecia quando a versao chegava (setState de _version) — com
    // PackageInfo lento (>2s Android) a splash ficava PRESA no logo
    // estatico sem codename/loading ate o boot timer abrir o app.
    // (regressao v0.1.9 reportada pelo usuario)
    setState(() {});

    // Boot mínimo visual. Será substituído pelo bootstrap real de catálogo.
    _bootTimer = Timer(
      const Duration(milliseconds: 2200),
      _completeInitialization,
    );
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fadeLogo = _fadeLogo;
    final fadeCodename = _fadeCodename;
    final fadeStatus = _fadeStatus;

    // Antes do boot timer (400ms): logo estatico (primeiro frame rapido).
    // A versao NUNCA bloqueia a animacao — bug v0.1.9: PackageInfo lento
    // (>2s no cold start) deixava a splash presa no logo sem codename.
    if (fadeLogo == null || fadeCodename == null || fadeStatus == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(child: const LouvorJaLogo(size: 140)),
      );
    }

    return Scaffold(
      // Luminous Clarity: superfície clara; Ethereal Lumens: #131313.
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: fadeLogo,
              child: const LouvorJaLogo(size: 140),
            ),
            const SizedBox(height: 32),

            FadeTransition(
              opacity: fadeCodename,
              child: const CodenamePiano(width: 220),
            ),
            const SizedBox(height: 48),

            FadeTransition(
              opacity: fadeStatus,
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'splash.loading'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_version.isNotEmpty)
                    Text(
                      _version,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
