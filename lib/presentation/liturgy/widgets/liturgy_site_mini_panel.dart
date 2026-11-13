import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_floating_panel.dart';
import 'liturgy_site_session.dart';
import 'liturgy_web_control_page.dart';

/// Site da Liturgia minimizado: painel flutuante para voltar à tela cheia
/// ou fechar.
class LiturgySiteMiniPanel extends StatelessWidget {
  const LiturgySiteMiniPanel({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  void _expand(LiturgySiteSession session) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    session.expand();
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => LiturgyWebControlPage.resume(session)),
    );
  }

  Future<void> _close(LiturgySiteSession session) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('liturgy-site-close-confirm'),
        title: Text('remote.video.closeConfirmTitle'.tr()),
        content: Text('liturgy.parity.closeLocalMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('remote.video.closeConfirmCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('remote.video.closeConfirmOk'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (session.projecting) session.stopProjection();
      session.close();
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<LiturgySiteSession?>(
        valueListenable: LiturgySiteSession.current,
        builder: (context, session, _) {
          if (session == null) return const SizedBox.shrink();
          return ListenableBuilder(
            listenable: session,
            builder: (context, _) {
              final theme = Theme.of(context);
              return RemoteFloatingPanel(
                key: const Key('liturgy-site-floating'),
                visible:
                    session.minimized &&
                    !session.closed &&
                    MediaQuery.viewInsetsOf(context).bottom == 0,
                estimatedHeight: 64,
                child: Material(
                  color: theme.colorScheme.surfaceContainerHigh,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.world,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('liturgy-site-expand'),
                          tooltip: 'common.expand'.tr(),
                          icon: const Icon(TablerIcons.maximize),
                          onPressed: () => _expand(session),
                        ),
                        IconButton(
                          key: const Key('liturgy-site-close'),
                          tooltip: 'common.close'.tr(),
                          icon: const Icon(TablerIcons.x),
                          onPressed: () => _close(session),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
}
