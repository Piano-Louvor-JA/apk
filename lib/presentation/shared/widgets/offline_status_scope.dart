// SPEC 7 (apk#92) — banner "modo offline" global: aparece sobre o conteúdo
// (topo da tela) em TODAS as tabs quando sem rede. Não bloqueia uso.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/offline_status.dart';
import 'offline_banner.dart';

/// Envelope do shell de navegação: escuta o status global e empurra o banner
/// acima do conteúdo (Stack), sem afetar layout das páginas.
class OfflineStatusScope extends StatefulWidget {
  const OfflineStatusScope({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineStatusScope> createState() => _OfflineStatusScopeState();
}

class _OfflineStatusScopeState extends State<OfflineStatusScope> {
  StreamSubscription<bool>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _sub = offlineStatus.onOfflineChanged.listen((offline) {
      if (mounted) setState(() => _offline = offline);
    });
    // start é idempotente: boot e scope podem chamar sem duplicar assinatura.
    unawaited(
      offlineStatus.start().then((_) {
        if (mounted && offlineStatus.isOffline != _offline) {
          setState(() => _offline = offlineStatus.isOffline);
        }
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: OfflineBanner(isOffline: _offline),
          ),
        ),
      ],
    );
  }
}
