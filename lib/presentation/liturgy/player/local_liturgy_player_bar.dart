import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/rich_notes.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/data/repositories/local_liturgy_media_impl.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';
import 'local_liturgy_player.dart';
import '../widgets/rich_notes_editor_page.dart';
import 'local_liturgy_session.dart';
import 'web_video_host.dart';

/// Mesmo player visual do remoto, com comandos exclusivamente locais.
class LocalLiturgyPlayerBar extends StatefulWidget {
  const LocalLiturgyPlayerBar({
    super.key,
    this.player,
    this.presence,
    this.compact = false,
    this.onExpand,
    this.onMinimize,
    this.navigatorKey,
  });
  final LocalLiturgyPlayer? player;
  final RemotePlayerPresence? presence;
  final bool compact;
  final VoidCallback? onExpand, onMinimize;
  final GlobalKey<NavigatorState>? navigatorKey;
  @override
  State<LocalLiturgyPlayerBar> createState() => _LocalLiturgyPlayerBarState();
}

class _LocalLiturgyPlayerBarState extends State<LocalLiturgyPlayerBar> {
  LocalLiturgyPlayer get player => widget.player ?? localLiturgyPlayer;
  final _videoFrame = ValueNotifier<Uint8List?>(null);
  @override
  void dispose() {
    _videoFrame.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {});
    final pending = player.openPending();
    setState(() {});
    try {
      await pending;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('liturgy.parity.fileUnavailable'.tr())),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _send(RemoteCommand command) async {
    try {
      await player.send(command);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('liturgy.parity.fileUnavailable'.tr())),
        );
      }
    }
  }

  Future<void> _edit() async {
    final item = player.active;
    if (item == null) return;
    String? title;
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RichNotesEditorPage(
          html: RichNotes.bodyOf(
            notesHtml: item.notesHtml,
            subtitle: item.subtitle,
            notes: item.notes,
          ),
          title: item.name,
          onTitleSaved: (value) => title = value,
        ),
      ),
    );
    final name = title?.trim() ?? '';
    if (value != null) {
      await player.updateText(
        item.copyWith(
          name: name.isEmpty ? item.name : name,
          notesHtml: value,
          subtitle: RichNotes.plainText(value),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LocalLiturgyPlayer, RemotePlayerState>(
        bloc: player,
        builder: (context, state) {
          Widget? preview;
          if (player.media case final LocalLiturgyMediaImpl media) {
            final video = media.video;
            final item = media.item;
            if (video != null && video.value.isInitialized) {
              preview = ColoredBox(
                color: Theme.of(context).colorScheme.scrim,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: video.value.aspectRatio,
                    child: VideoPlayer(video),
                  ),
                ),
              );
            } else if (media.web case final page?) {
              preview = ColoredBox(
                color: Theme.of(context).colorScheme.scrim,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: WebVideoSlot(key: ObjectKey(page)),
                  ),
                ),
              );
            } else if (item != null &&
                {
                  LiturgyItemType.annotation,
                  LiturgyItemType.notice,
                  LiturgyItemType.prayer,
                }.contains(item.type)) {
              preview = _RichPreview(key: ValueKey(item), item: item);
            }
          }
          return RemotePlayerBar(
            // Escolher um item na lista reabre a barra minimizada.
            key: widget.compact
                ? null
                : ValueKey('local-player-${player.revealCount}'),
            state: state,
            previewMaxHeight: MediaQuery.sizeOf(context).height * .16,
            showTransport: true,
            send: _send,
            presence: widget.presence ?? localLiturgyPresence,
            states: player.stream,
            videoFrame: _videoFrame,
            displayTitle: player.pending?.name,
            closeMessageKey: 'liturgy.parity.closeLocalMessage',
            onEdit:
                player.active?.type == LiturgyItemType.annotation &&
                    player.onChanged != null
                ? _edit
                : null,
            pendingOpen: player.pending == null ? null : _open,
            busy: player.busy,
            compact: widget.compact,
            showScreenTargets: false,
            onExpand: widget.onExpand,
            onMinimize: widget.onMinimize,
            navigatorKey: widget.navigatorKey,
            preview: preview,
          );
        },
      );
}

class _RichPreview extends StatefulWidget {
  const _RichPreview({super.key, required this.item});
  final LiturgyItem item;
  @override
  State<_RichPreview> createState() => _RichPreviewState();
}

class _RichPreviewState extends State<_RichPreview> {
  late final WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (_) => NavigationDecision.prevent,
      ),
    );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final body = RichNotes.bodyOf(
      notesHtml: widget.item.notesHtml,
      subtitle: widget.item.subtitle,
      notes: widget.item.notes,
    );
    final title = RichNotes.fromPlainText(widget.item.name);
    final colors = Theme.of(context).colorScheme;
    String hex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2)}';
    controller.loadHtmlString(
      '<html><meta name="viewport" content="width=device-width,initial-scale=1"><body style="background:${hex(colors.surface)};color:${hex(colors.onSurface)};font-family:sans-serif;text-align:center;font-size:20px"><h2 style="color:${RichNotes.titleColor(widget.item.titleColor).isEmpty ? hex(colors.onSurface) : RichNotes.titleColor(widget.item.titleColor)}">$title</h2>$body</body></html>',
    );
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: controller);
}
