library;

import 'dart:async';
import '../core/services/sync/operator_state_boot.dart';
import '../core/services/remote/remote_session.dart';
import '../presentation/bible/bible_download_controller.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import '../core/services/pip_controller.dart';
import '../core/services/settings_controller.dart';
import '../presentation/shared/widgets/pip_minimal_overlay.dart';
import '../presentation/remote/widgets/remote_mini_player_overlay.dart';
import '../presentation/liturgy/player/local_liturgy_overlay.dart';
import '../presentation/splash/splash_screen.dart';
import 'router.dart';
import 'theme/app_accents.dart';
import 'theme/app_theme.dart';

class LouvorjaApp extends StatefulWidget {
  const LouvorjaApp({super.key});

  @override
  State<LouvorjaApp> createState() => _LouvorjaAppState();
}

class _LouvorjaAppState extends State<LouvorjaApp> with WidgetsBindingObserver {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(RemoteSession.instance.restoreLastDesktopConnection());
    // Libera a splash nativa após o primeiro frame. A splash Flutter interna
    // assume a apresentação com logo LouvorJA + codename PIANO + loader.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(RemoteSession.instance.restoreLastDesktopConnection());
      unawaited(OperatorStateBoot.flushOnResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _hideSplash() {
    if (mounted) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final accent = AppAccents.byId(settings.accent.name);

    return MaterialApp.router(
      title: 'LouvorJA PIANO',
      scaffoldMessengerKey: appScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: accent),
      darkTheme: AppTheme.dark(accent: accent),
      themeMode: settings.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: appRouter,
      builder: (context, child) {
        if (_showSplash) {
          return SplashScreen(onInitializationComplete: _hideSplash);
        }
        // SPEC 13 (apk#132): em PiP, QUALQUER tela renderiza o layout mínimo
        // — se o usuário fechar o NowPlaying dentro da janelinha, a home
        // aparecia inteira (congestionada). O overlay cobre todas as rotas.
        return ValueListenableBuilder<bool>(
          valueListenable: PipController.isActive,
          builder: (context, isPip, _) {
            if (!isPip) {
              return RemoteMiniPlayerOverlay(
                navigatorKey: rootNavigatorKey,
                child: LocalLiturgyOverlay(
                  navigatorKey: rootNavigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            }
            return const PipMinimalOverlay();
          },
        );
      },
    );
  }
}
