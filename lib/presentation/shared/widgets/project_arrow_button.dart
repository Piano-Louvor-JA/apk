import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Setinha de projetar (mesma do Controle Remoto e dos players): pulsa
/// enquanto não projeta; projetando, vira a seta para baixo (parar).
class ProjectArrowButton extends StatefulWidget {
  const ProjectArrowButton({
    super.key,
    required this.projecting,
    required this.onPressed,
    this.busy = false,
  });

  final bool projecting;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  State<ProjectArrowButton> createState() => _ProjectArrowButtonState();
}

class _ProjectArrowButtonState extends State<ProjectArrowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1.3,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  bool get _pulsing => !widget.projecting && !widget.busy;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ProjectArrowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_pulsing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final button = IconButton(
      key: const Key('project-arrow'),
      tooltip: (widget.projecting ? 'remote.stopProjection' : 'remote.project')
          .tr(),
      isSelected: widget.projecting,
      style: IconButton.styleFrom(
        backgroundColor: primary.withValues(alpha: 0.22),
        side: BorderSide(color: primary, width: 2),
      ),
      onPressed: widget.busy ? null : widget.onPressed,
      icon: widget.busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            )
          : Icon(
              widget.projecting
                  ? TablerIcons.arrowDown
                  : TablerIcons.arrowUpRight,
              color: primary,
            ),
    );
    if (!_pulsing) return button;
    return ScaleTransition(
      key: const Key('project-arrow-pulse'),
      scale: _scale,
      child: button,
    );
  }
}
