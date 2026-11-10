import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'remote_player_bar.dart';

class RemoteMiniPlayerOverlay extends StatefulWidget {
  const RemoteMiniPlayerOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.session,
    this.presence,
  });
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final RemoteSession? session;
  final RemotePlayerPresence? presence;

  @override
  State<RemoteMiniPlayerOverlay> createState() =>
      _RemoteMiniPlayerOverlayState();
}

class _RemoteMiniPlayerOverlayState extends State<RemoteMiniPlayerOverlay> {
  RemoteSession get _session => widget.session ?? RemoteSession.instance;
  RemotePlayerPresence get _presence => widget.presence ?? remotePlayerPresence;
  StreamSubscription<RemotePlayerState>? _states;
  StreamSubscription<RemoteSessionStatus>? _status;
  RemotePlayerState? _state;
  bool _expanded = false;
  ModalRoute<void>? _sheet;

  @override
  void initState() {
    super.initState();
    _state = _session.lastState;
    _states = _session.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (!state.hasOpenMedia) _dismissSheet();
    });
    _status = _session.status.listen((_) {
      if (!mounted) return;
      setState(() => _state = _session.lastState);
      if (!_session.isControlling) _dismissSheet();
    });
  }

  void _dismissSheet() {
    final sheet = _sheet;
    if (sheet != null && sheet.isCurrent) sheet.navigator?.pop();
  }

  @override
  void dispose() {
    _states?.cancel();
    _status?.cancel();
    super.dispose();
  }

  Future<void> _expand() async {
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    setState(() => _expanded = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        _sheet = ModalRoute.of<void>(context);
        return StreamBuilder<RemotePlayerState>(
          stream: _session.states,
          initialData: _state,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == null || !state.hasOpenMedia) {
              return const SizedBox.shrink();
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              child: SingleChildScrollView(
                child: RemotePlayerBar(
                  state: state,
                  showTransport: true,
                  onMinimize: _dismissSheet,
                  send: _session.send,
                  videoFrame: _session.videoFrame,
                ),
              ),
            );
          },
        );
      },
    );
    _sheet = null;
    if (mounted) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _presence,
      builder: (context, fullPlayerVisible, _) {
        final state = _state;
        final media = MediaQuery.of(context);
        final visible =
            !_expanded &&
            !fullPlayerVisible &&
            media.viewInsets.bottom == 0 &&
            _session.isControlling &&
            state != null &&
            state.hasOpenMedia;
        return _OverlaySurface(
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (visible)
                Positioned(
                  right: 12,
                  bottom: media.padding.bottom + 76,
                  width: math.min(320, media.size.width - 24),
                  child: RemotePlayerBar(
                    state: state,
                    compact: true,
                    onExpand: _expand,
                    navigatorKey: widget.navigatorKey,
                    send: _session.send,
                    videoFrame: _session.videoFrame,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Acima do Navigator, os tooltips precisam de um Overlay próprio.
// Mantém o mesmo Navigator e o estado das rotas durante as atualizações.
class _OverlaySurface extends StatefulWidget {
  const _OverlaySurface({required this.child});
  final Widget child;
  @override
  State<_OverlaySurface> createState() => _OverlaySurfaceState();
}

class _OverlaySurfaceState extends State<_OverlaySurface> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);
  @override
  void didUpdateWidget(_OverlaySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
