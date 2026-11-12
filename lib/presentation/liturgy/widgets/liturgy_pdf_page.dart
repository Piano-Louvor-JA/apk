import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_pdf_document.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/presentation/shared/widgets/stage_cast_button.dart';

class LiturgyPdfPage extends StatefulWidget {
  const LiturgyPdfPage({super.key, required this.path, required this.title});
  final String path;
  final String title;
  @override
  State<LiturgyPdfPage> createState() => _LiturgyPdfPageState();
}

class _LiturgyPdfPageState extends State<LiturgyPdfPage> {
  late final _document = LiturgyPdfDocument(widget.path);
  late final Future<int> _count = _document.pageCount();
  int _index = 0;
  late Future<Uint8List> _page = _document.render(0);
  bool _projecting = false;
  late final WebViewController? _ios = Platform.isIOS
      ? (WebViewController()..loadFile(widget.path))
      : null;
  Future<void> _project() async {
    try {
      final bytes = await _page;
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/liturgy-pdf-${widget.path.hashCode}-$_index.png',
      );
      await file.writeAsBytes(bytes);
      final count = StageSession.instance.projectImageFiles([file.path]);
      if (!mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('liturgy.parity.connectScreens'.tr())),
        );
      } else {
        setState(() => _projecting = true);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('liturgy.parity.fileUnavailable'.tr())),
        );
    }
  }

  void _move(int index) {
    setState(() {
      _index = index;
      _page = _document.render(index);
    });
    if (_projecting) _project();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        const StageCastButton(),
        if (_ios == null)
          IconButton(
            tooltip: 'liturgy.parity.project'.tr(),
            onPressed: _project,
            icon: const Icon(TablerIcons.presentation),
          ),
        IconButton(
          tooltip: 'liturgy.parity.stopProjection'.tr(),
          onPressed: () {
            StageSession.instance.clearContent();
            setState(() => _projecting = false);
          },
          icon: const Icon(TablerIcons.playerStop),
        ),
      ],
    ),
    body: _ios != null
        ? WebViewWidget(controller: _ios)
        : FutureBuilder<int>(
            future: _count,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: Text('liturgy.parity.fileUnavailable'.tr()),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final count = snapshot.data!;
              if (count <= 0)
                return Center(
                  child: Text('liturgy.parity.fileUnavailable'.tr()),
                );
              return Column(
                children: [
                  Expanded(
                    child: FutureBuilder<Uint8List>(
                      future: _page,
                      builder: (context, page) {
                        if (page.hasError)
                          return Center(
                            child: Text('liturgy.parity.fileUnavailable'.tr()),
                          );
                        if (!page.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        return InteractiveViewer(
                          child: Center(
                            child: Image.memory(
                              page.data!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'remote.previous'.tr(),
                        onPressed: _index > 0 ? () => _move(_index - 1) : null,
                        icon: const Icon(TablerIcons.chevronLeft),
                      ),
                      Text('${_index + 1} / $count'),
                      IconButton(
                        tooltip: 'remote.next'.tr(),
                        onPressed: _index + 1 < count
                            ? () => _move(_index + 1)
                            : null,
                        icon: const Icon(TablerIcons.chevronRight),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
  );
}
