import 'package:flutter/material.dart';

/// Marca o menu do rodapé para o player expandido parar acima dele.
class MainNavigationInset extends StatefulWidget {
  const MainNavigationInset({super.key, required this.child});
  final Widget child;

  static _MainNavigationInsetState? _current;

  /// Altura do rodapé visível agora; 0 quando outra tela o cobre.
  static double get visibleHeight {
    final state = _current;
    if (state == null || !state.mounted) return 0;
    if (ModalRoute.of(state.context)?.isCurrent == false) return 0;
    final box = state.context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }

  @override
  State<MainNavigationInset> createState() => _MainNavigationInsetState();
}

class _MainNavigationInsetState extends State<MainNavigationInset> {
  @override
  void initState() {
    super.initState();
    MainNavigationInset._current = this;
  }

  @override
  void dispose() {
    if (MainNavigationInset._current == this) {
      MainNavigationInset._current = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Player expandido (Controle Remoto e Liturgia local): sobe da base, mas
/// fica acima do menu do rodapé, que continua livre (sem película e tocável).
Future<void> showPlayerSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context);
  return navigator.push(
    _PlayerSheetRoute(
      inset: MainNavigationInset.visibleHeight,
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: MaterialLocalizations.of(context).scrimLabel,
      isScrollControlled: true,
      useSafeArea: true,
    ),
  );
}

class _PlayerSheetRoute extends ModalBottomSheetRoute<void> {
  _PlayerSheetRoute({
    required this.inset,
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.useSafeArea,
  });

  /// Altura do rodapé: nem a película nem o sheet passam dela.
  final double inset;

  @override
  Widget buildModalBarrier() => Padding(
    padding: EdgeInsets.only(bottom: inset),
    child: super.buildModalBarrier(),
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = super.buildPage(context, animation, secondaryAnimation);
    if (inset <= 0) return page;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ClipRect(
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: page,
        ),
      ),
    );
  }
}
