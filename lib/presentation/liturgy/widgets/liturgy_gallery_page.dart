import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';

class LiturgyGalleryPage extends StatefulWidget {
  const LiturgyGalleryPage({
    super.key,
    required this.title,
    required this.paths,
  });
  final String title;
  final List<String> paths;
  @override
  State<LiturgyGalleryPage> createState() => _LiturgyGalleryPageState();
}

class _LiturgyGalleryPageState extends State<LiturgyGalleryPage> {
  final _pages = PageController();
  int _index = 0;
  bool _projecting = false;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _project() {
    final count = StageSession.instance.projectImageFiles(
      widget.paths,
      initialIndex: _index,
    );
    if (count > 0) {
      setState(() => _projecting = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('liturgy.parity.connectScreens'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'liturgy.parity.project'.tr(),
          onPressed: _project,
          icon: const Icon(TablerIcons.presentation),
        ),
        IconButton(
          tooltip: 'liturgy.parity.stopProjection'.tr(),
          onPressed: () {
            StageSession.instance.stopSlides();
            setState(() => _projecting = false);
          },
          icon: const Icon(TablerIcons.playerStop),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.paths.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              if (_projecting) StageSession.instance.showSlide(index);
            },
            itemBuilder: (_, index) => InteractiveViewer(
              child: Image.file(
                File(widget.paths[index]),
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) =>
                    Center(child: Text('liturgy.parity.fileUnavailable'.tr())),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'remote.previous'.tr(),
              onPressed: _index > 0
                  ? () => _pages.previousPage(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                    )
                  : null,
              icon: const Icon(TablerIcons.chevronLeft),
            ),
            Text('${_index + 1} / ${widget.paths.length}'),
            IconButton(
              tooltip: 'remote.next'.tr(),
              onPressed: _index + 1 < widget.paths.length
                  ? () => _pages.nextPage(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                    )
                  : null,
              icon: const Icon(TablerIcons.chevronRight),
            ),
          ],
        ),
      ],
    ),
  );
}
