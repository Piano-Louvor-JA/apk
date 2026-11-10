import 'dart:async';
import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'remote_bible_preview.dart';
import 'remote_floating_panel.dart';

/// Bíblia flutuante independente da mídia, usando o mesmo capítulo do desktop.
class RemoteBibleFloatingPanel extends StatefulWidget {
  const RemoteBibleFloatingPanel({
    super.key,
    required this.session,
    required this.navigatorKey,
    this.bottomGap = 76,
  });
  final RemoteSession session;
  final GlobalKey<NavigatorState> navigatorKey;
  final double bottomGap;
  @override
  State<RemoteBibleFloatingPanel> createState() =>
      _RemoteBibleFloatingPanelState();
}

class _RemoteBibleFloatingPanelState extends State<RemoteBibleFloatingPanel> {
  StreamSubscription<RemotePlayerState>? _states;
  StreamSubscription<RemoteSessionStatus>? _status;
  RemotePlayerState? _state;
  bool _expanded = false;
  ModalRoute<void>? _sheet;

  @override
  void initState() {
    super.initState();
    _state = widget.session.lastState;
    _states = widget.session.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _status = widget.session.status.listen((_) {
      if (!mounted) return;
      if (!widget.session.isControlling) {
        remoteBibleMinimized.value = false;
        _dismiss();
      }
      setState(() => _state = widget.session.lastState);
    });
    remoteBiblePresence.addListener(_refresh);
    remoteBibleMinimized.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _dismiss() {
    final sheet = _sheet;
    if (sheet != null && sheet.isCurrent) sheet.navigator?.pop();
  }

  @override
  void dispose() {
    _states?.cancel();
    _status?.cancel();
    remoteBiblePresence.removeListener(_refresh);
    remoteBibleMinimized.removeListener(_refresh);
    super.dispose();
  }

  void _send(RemoteAction action, {RemoteBibleState? bible, int? verse}) {
    widget.session.send(
      RemoteCommand(
        id: 'b${DateTime.now().microsecondsSinceEpoch}',
        action: action,
        bookId: bible?.bookId,
        versionId: bible?.versionId,
        chapter: bible?.chapter,
        verse:
            verse ??
            (bible?.selectedVerses.isNotEmpty == true
                ? bible!.selectedVerses.last
                : 1),
      ),
    );
  }

  void _toggle(RemoteBibleState bible) => _send(
    bible.isProjecting ? RemoteAction.bibleClose : RemoteAction.bibleOpen,
    bible: bible,
  );

  void _close() {
    remoteBibleMinimized.value = false;
    _send(RemoteAction.bibleClose);
    _dismiss();
  }

  String _bookName(RemoteBibleState bible) {
    for (final book in bible.books) {
      if (book.id == bible.bookId) return book.name;
    }
    return '';
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
          stream: widget.session.states,
          initialData: _state,
          builder: (_, snapshot) {
            final bible = snapshot.data?.bibleModule;
            if (bible == null) return const SizedBox.shrink();
            return SafeArea(
              child: RemoteBiblePreview(
                bible: bible,
                bookName: _bookName(bible),
                onChanged: (verse) =>
                    _send(RemoteAction.bibleSelectVerse, verse: verse),
                onMinimize: _dismiss,
                onClose: _close,
                onProject: () => _toggle(bible),
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
    final bible = _state?.bibleModule;
    final visible =
        !_expanded &&
        widget.session.isControlling &&
        bible != null &&
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        (remoteBibleMinimized.value ||
            (bible.isProjecting && !remoteBiblePresence.value));
    return RemoteFloatingPanel(
      visible: visible,
      bottomGap: widget.bottomGap,
      estimatedHeight: 220,
      child: bible == null
          ? const SizedBox.shrink()
          : RemoteBiblePreview(
              bible: bible,
              bookName: _bookName(bible),
              compact: true,
              onChanged: (verse) =>
                  _send(RemoteAction.bibleSelectVerse, verse: verse),
              onExpand: _expand,
              onClose: _close,
              onProject: () => _toggle(bible),
            ),
    );
  }
}
