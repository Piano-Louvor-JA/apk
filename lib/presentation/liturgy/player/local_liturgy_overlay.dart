import 'dart:async';
import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_floating_panel.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/player_sheet.dart';
import 'local_liturgy_player_bar.dart';
import 'local_liturgy_session.dart';

/// Mantém o mesmo áudio/vídeo ao trocar de aba ou expandir o painel.
class LocalLiturgyOverlay extends StatefulWidget {
  const LocalLiturgyOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  State<LocalLiturgyOverlay> createState() => _LocalLiturgyOverlayState();
}

class _LocalLiturgyOverlayState extends State<LocalLiturgyOverlay> {
  bool expanded = false;
  ModalRoute<void>? sheet;
  late final StreamSubscription<RemotePlayerState> subscription =
      localLiturgyPlayer.stream.listen((state) {
        if (!localLiturgyPlayer.hasContent && sheet?.isCurrent == true) {
          sheet?.navigator?.pop();
        }
        if (mounted) setState(() {});
      });
  late final OverlayEntry entry = OverlayEntry(builder: (_) => _content());
  @override
  void initState() {
    super.initState();
    subscription;
    localLiturgyPresence.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(LocalLiturgyOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry.markNeedsBuild();
  }

  Future<void> _expand() async {
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    setState(() => expanded = true);
    await showPlayerSheet(
      context: context,
      builder: (context) {
        sheet = ModalRoute.of<void>(context);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: SingleChildScrollView(
            child: LocalLiturgyPlayerBar(
              onMinimize: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
    sheet = null;
    if (mounted) setState(() => expanded = false);
  }

  Widget _content() => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      RemoteFloatingPanel(
        key: const Key('local-liturgy-floating'),
        visible:
            !expanded &&
            !localLiturgyPresence.value &&
            // Também com o item só escolhido: minimizar não some com ele.
            localLiturgyPlayer.hasContent &&
            MediaQuery.viewInsetsOf(context).bottom == 0,
        child: LocalLiturgyPlayerBar(
          compact: true,
          onExpand: _expand,
          navigatorKey: widget.navigatorKey,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    entry.markNeedsBuild();
    return Overlay(initialEntries: [entry]);
  }

  @override
  void dispose() {
    subscription.cancel();
    localLiturgyPresence.removeListener(_update);
    entry.remove();
    entry.dispose();
    super.dispose();
  }
}
