// coverage:ignore-file
// UI de Ferramentas -- galeria de cards clicaveis, cada ferramenta em view propria
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:louvorja_piano_mobile/presentation/bible/bible_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';
import 'package:louvorja_piano_mobile/presentation/timer/timer_page.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_control_tool_page.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  _ToolView? _activeView;

  @override
  Widget build(BuildContext context) {
    if (_activeView != null) {
      return _buildToolView(_activeView!);
    }
    return _buildGallery();
  }

  Widget _buildGallery() {
    final theme = Theme.of(context);
    final tools = _ToolView.values;

    return Scaffold(
      appBar: AppBar(
        title: Text('tools.title'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          final accent = theme.colorScheme;
          return _ToolCard(
            icon: tool.icon,
            title: tool.label.tr(),
            subtitle: tool.subtitle.tr(),
            color: tool.color(accent),
            onTap: () => setState(() => _activeView = tool),
          );
        },
      ),
    );
  }

  Widget _buildToolView(_ToolView view) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('tool-back'),
          icon: const Icon(TablerIcons.arrowLeft),
          onPressed: () => setState(() => _activeView = null),
        ),
        title: Text(view.label.tr()),
        // F3.3l: o botão do Palco vive na AppBar da PRÓPRIA ferramenta
        // (Bíblia/Liturgia/Timer já têm StageCastButton) — um cast só.
      ),
      body: switch (view) {
        _ToolView.liturgy => const LiturgyPage(),
        _ToolView.remoteControl => const RemoteControlToolPage(),
        _ToolView.bible => const BiblePage(),
        _ToolView.timer => const TimerPage(),
      },
    );
  }
}

enum _ToolView {
  liturgy,
  bible,
  timer,
  remoteControl;

  IconData get icon => switch (this) {
    liturgy => TablerIcons.clipboardText,
    bible => TablerIcons.book2,
    timer => TablerIcons.clock,
    remoteControl => TablerIcons.deviceGamepad2,
  };

  String get label => switch (this) {
    liturgy => 'tools.liturgy',
    bible => 'tools.bible',
    timer => 'tools.timer',
    remoteControl => 'tools.remoteControl',
  };

  String get subtitle => switch (this) {
    liturgy => 'tools.liturgySubtitle',
    bible => 'tools.bibleSubtitle',
    timer => 'tools.timerSubtitle',
    remoteControl => 'tools.remoteControlSubtitle',
  };

  Color color(ColorScheme scheme) => switch (this) {
    liturgy => scheme.primary,
    bible => scheme.tertiary,
    timer => scheme.secondary,
    remoteControl => scheme.error,
  };
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
