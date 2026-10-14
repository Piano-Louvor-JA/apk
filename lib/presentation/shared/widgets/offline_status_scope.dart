// SPEC 7 (apk#92) — banner "modo offline" global: aparece sobre o conteúdo
// (topo da tela) em TODAS as tabs quando sem rede. Não bloqueia uso.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/offline_status.dart';
import '../../../../core/services/connectivity_service.dart';
import 'offline_banner.dart';

/// Envelope do shell de navegação: escuta o status global e empurra o banner
/// acima do conteúdo (Stack), sem afetar layout das páginas.
class OfflineStatusScope extends StatefulWidget {
  const OfflineStatusScope({super.key, required this.child, this.controller});

  final Widget child;
  final OfflineStatusController? controller;

  @override
  State<OfflineStatusScope> createState() => _OfflineStatusScopeState();
}

class _OfflineStatusScopeState extends State<OfflineStatusScope> {
  StreamSubscription<bool>? _sub;
  bool _offline = false;
  late final OfflineStatusController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? offlineStatus;
    _offline = _controller.isOffline;
    _sub = _controller.onOfflineChanged.listen((offline) {
      if (mounted) setState(() => _offline = offline);
    });
    // start é idempotente: boot e scope podem chamar sem duplicar assinatura.
    unawaited(
      _controller.start().then((_) {
        if (mounted && _controller.isOffline != _offline) {
          setState(() => _offline = _controller.isOffline);
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
            child: IgnorePointer(child: OfflineBanner(isOffline: _offline)),
          ),
        ),
      ],
    );
  }
}
