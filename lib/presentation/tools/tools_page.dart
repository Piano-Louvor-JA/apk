// coverage:ignore-file
// UI de Ferramentas -- galeria de cards clicaveis, cada ferramenta em view propria
library;

import 'desktop_monitors_page.dart';
import 'palco_page.dart';
import 'transmission_page.dart';
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

  /// Dentro do agregador Conexões (Transmissão, Conectar monitor e Palco).
  bool _inConnections = false;

  @override
  Widget build(BuildContext context) {
    if (_activeView != null) {
      return _buildToolView(_activeView!);
    }
    return _buildGallery();
  }

  void _open(_ToolView tool) {
    setState(() {
      if (tool == _ToolView.connections) {
        _inConnections = true;
      } else {
        _activeView = tool;
      }
    });
  }

  Widget _buildGallery() {
    final theme = Theme.of(context);
    final tools = _ToolView.values
        .where((t) => _inConnections ? t.inConnections : !t.inConnections)
        .toList();

    // Voltar do Android dentro de Conexões: volta à galeria, não sai do app.
    return PopScope(
      canPop: !_inConnections,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _inConnections) setState(() => _inConnections = false);
      },
      child: _galleryScaffold(theme, tools),
    );
  }

  Widget _galleryScaffold(ThemeData theme, List<_ToolView> tools) {
    return Scaffold(
      appBar: AppBar(
        leading: _inConnections
            ? IconButton(
                key: const Key('tools-connections-back'),
                icon: const Icon(TablerIcons.arrowLeft),
                onPressed: () => setState(() => _inConnections = false),
              )
            : null,
        title: Text(
          (_inConnections ? 'tools.connections' : 'tools.title').tr(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: GridView.builder(
        // Cada nível com rolagem própria: Conexões abre do topo.
        key: ValueKey(_inConnections),
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
            key: Key('tool-card-${tool.name}'),
            icon: tool.icon,
            title: tool.label.tr(),
            subtitle: tool.subtitle.tr(),
            color: tool.color(accent),
            onTap: () => _open(tool),
          );
        },
      ),
    );
  }

  Widget _buildToolView(_ToolView view) {
    if (view == _ToolView.timer) {
      return TimerPage(onBack: () => setState(() => _activeView = null));
    }
    if (view == _ToolView.desktopMonitors) {
      return DesktopMonitorsPage(
        onBack: () => setState(() => _activeView = null),
      );
    }
    if (view == _ToolView.transmission) {
      return TransmissionPage(onBack: () => setState(() => _activeView = null));
    }
    if (view == _ToolView.palco) {
      return PalcoPage(onBack: () => setState(() => _activeView = null));
    }
    if (view == _ToolView.remoteControl) {
      return RemoteControlToolPage(
        onBack: () => setState(() => _activeView = null),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('tool-back'),
          icon: const Icon(TablerIcons.arrowLeft),
          onPressed: () => setState(() => _activeView = null),
        ),
        title: Text(view.label.tr()),
        // O destino da projeção é escolhido no botão Telas da navegação.
      ),
      body: switch (view) {
        _ToolView.liturgy => const LiturgyPage(),
        _ToolView.remoteControl => const RemoteControlToolPage(),
        _ToolView.bible => const BiblePage(),
        _ToolView.timer => const TimerPage(),
        _ToolView.transmission => const TransmissionPage(),
        _ToolView.desktopMonitors => const DesktopMonitorsPage(),
        _ToolView.palco => const PalcoPage(),
        // Agregador: aberto por _open, nunca vira view própria.
        _ToolView.connections => const SizedBox.shrink(),
      },
    );
  }
}

enum _ToolView {
  liturgy,
  bible,
  timer,
  remoteControl,
  connections,
  transmission,
  desktopMonitors,
  palco;

  /// Fica dentro do card Conexões, não na galeria principal.
  bool get inConnections =>
      this == transmission || this == desktopMonitors || this == palco;

  IconData get icon => switch (this) {
    liturgy => TablerIcons.clipboardText,
    bible => TablerIcons.book2,
    timer => TablerIcons.clock,
    remoteControl => TablerIcons.deviceGamepad2,
    connections => TablerIcons.plugConnected,
    transmission => TablerIcons.broadcast,
    desktopMonitors => TablerIcons.devicesPc,
    palco => TablerIcons.deviceTv,
  };

  String get label => switch (this) {
    liturgy => 'tools.liturgy',
    bible => 'tools.bible',
    timer => 'tools.timer',
    remoteControl => 'tools.remoteControl',
    connections => 'tools.connections',
    transmission => 'tools.transmission',
    desktopMonitors => 'tools.desktopMonitors',
    palco => 'tools.palco',
  };

  String get subtitle => switch (this) {
    liturgy => 'tools.liturgySubtitle',
    bible => 'tools.bibleSubtitle',
    timer => 'tools.timerSubtitle',
    remoteControl => 'tools.remoteControlSubtitle',
    connections => 'tools.connectionsSubtitle',
    transmission => 'tools.transmissionSubtitle',
    desktopMonitors => 'tools.desktopMonitorsSubtitle',
    palco => 'tools.palcoSubtitle',
  };

  Color color(ColorScheme scheme) => switch (this) {
    liturgy => scheme.primary,
    bible => scheme.tertiary,
    timer => scheme.secondary,
    remoteControl => scheme.error,
    connections => scheme.primary,
    transmission => scheme.primary,
    desktopMonitors => scheme.tertiary,
    palco => scheme.secondary,
  };
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    super.key,
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
