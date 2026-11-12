import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/rich_notes.dart';

/// Editor offline com o mesmo HTML e comandos do editor de Liturgia desktop.
class RichNotesEditorPage extends StatefulWidget {
  const RichNotesEditorPage({super.key, required this.html});
  final String html;
  @override
  State<RichNotesEditorPage> createState() => _RichNotesEditorPageState();
}

class _RichNotesEditorPageState extends State<RichNotesEditorPage> {
  late final WebViewController _controller;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PasteNotes',
        onMessageReceived: (message) {
          try {
            final payload = jsonDecode(message.message) as Map;
            final raw = payload['html'] as String? ?? '';
            final clean = raw.isNotEmpty
                ? RichNotes.sanitize(raw)
                : RichNotes.fromPlainText(payload['text'] as String? ?? '');
            _run('insertHTML', clean);
          } catch (_) {
            /* mensagem inválida não altera o editor */
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url.startsWith('about:') ||
                  request.url.startsWith('data:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final scheme = Theme.of(context).colorScheme;
    String color(Color c) => '#${c.toARGB32().toRadixString(16).substring(2)}';
    final initial = RichNotes.sanitize(widget.html);
    _controller.loadHtmlString(
      '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{margin:0;background:${color(scheme.surface)};color:${color(scheme.onSurface)};font-family:sans-serif}#editor{padding:16px;min-height:80vh;font-size:18px;outline:none;overflow-wrap:anywhere}p,div{margin-top:0}li{margin:4px 0}</style></head><body><div id="editor" contenteditable="true">$initial</div><script>document.getElementById('editor').addEventListener('paste',event=>{event.preventDefault();PasteNotes.postMessage(JSON.stringify({html:event.clipboardData.getData('text/html'),text:event.clipboardData.getData('text/plain')}))});let savedRange=null;document.addEventListener('selectionchange',()=>{const s=window.getSelection();if(s.rangeCount&&document.getElementById('editor').contains(s.anchorNode))savedRange=s.getRangeAt(0).cloneRange()});window.runFormat=(command,value)=>{const editor=document.getElementById('editor');editor.focus();if(savedRange){const s=window.getSelection();s.removeAllRanges();s.addRange(savedRange)}document.execCommand('styleWithCSS',false,true);document.execCommand(command,false,value??null)};</script></body></html>''',
    );
  }

  Future<void> _run(String command, [String? value]) =>
      _controller.runJavaScript(
        'window.runFormat(${jsonEncode(command)},${jsonEncode(value)})',
      );
  Future<void> _save() async {
    final value = await _controller.runJavaScriptReturningResult(
      'JSON.stringify(document.getElementById("editor").innerHTML)',
    );
    var html = value.toString();
    try {
      final decoded = jsonDecode(html);
      if (decoded is String) html = decoded;
    } catch (_) {
      /* iOS pode retornar a string já decodificada */
    }
    if (mounted) Navigator.pop(context, RichNotes.sanitize(html));
  }

  Future<void> _colors({bool highlight = false}) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (highlight)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'transparent'),
                  child: Text('liturgy.richNotes.noHighlight'.tr()),
                ),
              for (final hex in RichNotes.colors)
                Semantics(
                  label: hex,
                  button: true,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse('ff${hex.substring(1)}', radix: 16),
                        ),
                        border: Border.all(
                          color: Theme.of(ctx).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null)
      await _run(highlight ? 'hiliteColor' : 'foreColor', selected);
  }

  Widget _tool(IconData icon, String key, String command) => IconButton(
    tooltip: 'liturgy.richNotes.$key'.tr(),
    onPressed: () => _run(command),
    icon: Icon(icon),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('liturgy.parity.formattedText'.tr()),
      actions: [
        IconButton(
          tooltip: 'liturgy.actions.save'.tr(),
          onPressed: _save,
          icon: const Icon(TablerIcons.check),
        ),
      ],
    ),
    body: Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            _tool(TablerIcons.bold, 'bold', 'bold'),
            _tool(TablerIcons.italic, 'italic', 'italic'),
            _tool(TablerIcons.underline, 'underline', 'underline'),
            _tool(TablerIcons.list, 'bulletList', 'insertUnorderedList'),
            _tool(TablerIcons.listNumbers, 'numberedList', 'insertOrderedList'),
            _tool(TablerIcons.alignLeft, 'alignLeft', 'justifyLeft'),
            _tool(TablerIcons.alignCenter, 'alignCenter', 'justifyCenter'),
            _tool(TablerIcons.alignRight, 'alignRight', 'justifyRight'),
            IconButton(
              tooltip: 'liturgy.richNotes.color'.tr(),
              onPressed: () => _colors(),
              icon: const Icon(TablerIcons.palette),
            ),
            IconButton(
              tooltip: 'liturgy.richNotes.highlight'.tr(),
              onPressed: () => _colors(highlight: true),
              icon: const Icon(TablerIcons.highlight),
            ),
            PopupMenuButton<String>(
              tooltip: 'liturgy.richNotes.size'.tr(),
              icon: const Icon(TablerIcons.textSize),
              onSelected: (size) => _run('fontSize', size),
              itemBuilder: (_) => [
                for (final entry in const {
                  '2': 'sizeSmall',
                  '3': 'sizeNormal',
                  '5': 'sizeLarge',
                  '6': 'sizeTitle',
                }.entries)
                  PopupMenuItem(
                    value: entry.key,
                    child: Text('liturgy.richNotes.${entry.value}'.tr()),
                  ),
              ],
            ),
            _tool(TablerIcons.clearFormatting, 'clear', 'removeFormat'),
          ],
        ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    ),
  );
}
