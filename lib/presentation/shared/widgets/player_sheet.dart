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
/// fica acima do menu do rodapé em vez de cobri-lo.
Future<void> showPlayerSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final inset = MainNavigationInset.visibleHeight;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final sheet = theme.bottomSheetTheme;
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Material(
          color:
              sheet.modalBackgroundColor ??
              sheet.backgroundColor ??
              theme.colorScheme.surfaceContainerLow,
          elevation: sheet.modalElevation ?? sheet.elevation ?? 1,
          shape:
              sheet.shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery.removePadding(
            context: sheetContext,
            removeBottom: inset > 0,
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}
