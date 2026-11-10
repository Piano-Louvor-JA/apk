import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Painel arrastável compartilhado: movimento direto e limites da área útil.
class RemoteFloatingPanel extends StatefulWidget {
  const RemoteFloatingPanel({
    super.key,
    required this.child,
    this.visible = true,
    this.bottomGap = 76,
    this.estimatedHeight = 128,
  });
  final Widget child;
  final bool visible;
  final double bottomGap;
  final double estimatedHeight;

  @override
  State<RemoteFloatingPanel> createState() => _RemoteFloatingPanelState();
}

class _RemoteFloatingPanelState extends State<RemoteFloatingPanel> {
  final _measureKey = GlobalKey();
  Offset? _position;
  late double _height = widget.estimatedHeight;

  Offset _clamp(Offset position, MediaQueryData media, double width) {
    final top = media.padding.top + 12;
    return Offset(
      position.dx.clamp(12.0, math.max(12.0, media.size.width - width - 12)),
      position.dy.clamp(
        top,
        math.max(top, media.size.height - media.padding.bottom - 76 - _height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final width = math.max(0.0, math.min(320.0, media.size.width - 24));
    final position = _clamp(
      _position ??
          Offset(
            media.size.width - width - 12,
            media.size.height -
                media.padding.bottom -
                widget.bottomGap -
                _height,
          ),
      media,
      width,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _measureKey.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.hasSize &&
          (box.size.height - _height).abs() > 0.5) {
        setState(() => _height = box.size.height);
      }
    });
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: width,
      child: GestureDetector(
        key: _measureKey,
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => setState(() {
          _position = _clamp(
            _clamp(_position ?? position, media, width) + details.delta,
            media,
            width,
          );
        }),
        child: widget.child,
      ),
    );
  }
}
