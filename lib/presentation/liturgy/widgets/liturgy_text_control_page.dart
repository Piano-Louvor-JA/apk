import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/rich_notes.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';
import 'rich_notes_editor_page.dart';

class LiturgyTextControlPage extends StatefulWidget {
  const LiturgyTextControlPage({super.key, required this.item, this.onChanged});
  final LiturgyItem item;
  final ValueChanged<LiturgyItem>? onChanged;
  @override
  State<LiturgyTextControlPage> createState() => _LiturgyTextControlPageState();
}

class _LiturgyTextControlPageState extends State<LiturgyTextControlPage> {
  late String _html = RichNotes.sanitize(widget.item.notesHtml).isNotEmpty
      ? RichNotes.sanitize(widget.item.notesHtml)
      : RichNotes.fromPlainText(widget.item.subtitle);
  late final _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.disabled)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) =>
            request.url.startsWith('about:') || request.url.startsWith('data:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    );
  bool _initialized = false;
  void _render() {
    final c = Theme.of(context).colorScheme;
    String hex(Color v) => '#${v.toARGB32().toRadixString(16).substring(2)}';
    final title = const HtmlEscape().convert(widget.item.name);
    final color = RichNotes.titleColor(widget.item.titleColor);
    _controller.loadHtmlString(
      '<html><meta name="viewport" content="width=device-width,initial-scale=1"><body style="background:${hex(c.surface)};color:${hex(c.onSurface)};font-family:sans-serif;padding:16px;font-size:22px"><h2 style="color:${color.isEmpty ? hex(c.onSurface) : color}">$title</h2>$_html</body></html>',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _render();
    }
  }

  Future<void> _project() async {
    final stage = StageSession.instance;
    if (!stage.isOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('liturgy.parity.connectScreens'.tr())),
      );
      return;
    }
    await stage.project(
      title: widget.item.name,
      body: RichNotes.plainText(_html),
      richBody: _html,
      titleColor: RichNotes.titleColor(widget.item.titleColor),
      module: 'liturgy',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.item.name),
      actions: [
        const StageCastButton(),
        IconButton(
          tooltip: 'liturgy.parity.project'.tr(),
          onPressed: _project,
          icon: const Icon(TablerIcons.presentation),
        ),
        IconButton(
          tooltip: 'liturgy.parity.stopProjection'.tr(),
          onPressed: () => StageSession.instance.clearContent(),
          icon: const Icon(TablerIcons.playerStop),
        ),
        if (widget.onChanged != null)
          IconButton(
            tooltip: 'liturgy.actions.edit'.tr(),
            onPressed: () async {
              final value = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => RichNotesEditorPage(html: _html),
                ),
              );
              if (value != null && mounted) {
                setState(() => _html = value);
                widget.onChanged?.call(
                  LiturgyItem.fromJson({
                    ...widget.item.toJson(),
                    'notesHtml': value,
                    'subtitle': RichNotes.plainText(value),
                  }),
                );
                _render();
              }
            },
            icon: const Icon(TablerIcons.edit),
          ),
      ],
    ),
    body: WebViewWidget(controller: _controller),
  );
}
