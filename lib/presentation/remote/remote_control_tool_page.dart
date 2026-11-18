// UI de controle remoto (ferramenta) — smoke de idle coberto em teste.
library;

import 'dart:async';

import 'remote_playlist_panel.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_liturgy_page.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_liturgy_days.dart';
import 'package:louvorja_piano_mobile/presentation/remote/widgets/remote_player_bar.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';
import 'package:louvorja_piano_mobile/core/services/terms_acceptance.dart';

/// Ferramenta "Controle Remoto": visível quando há sessão conectada.
/// Layout de controle remoto — liturgia espelhada + controles de mídia.
class RemoteControlToolPage extends StatefulWidget {
  const RemoteControlToolPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<RemoteControlToolPage> createState() => _RemoteControlToolPageState();
}

class _RemoteControlToolPageState extends State<RemoteControlToolPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Abas que controlam musica: Liturgia e Hinos.
  // Liturgia só escolhe o dia; quem toca é a lista espelhada, com barra própria.
  static const _playerTabs = {0, 3};

  StreamSubscription? _sub;
  RemotePlayerState? _state;
  TabController? _tabCtrl;
  bool _keyboardOpen = false;
  RemoteHymnSelection? _hymnSelection;
  RemotePlaylistSelection? _playlistSelection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // TabBar exige controller (sem ele lança e a view fica cinza).
    _tabCtrl = TabController(length: 5, initialIndex: 2, vsync: this);
    _tabCtrl!.addListener(() {
      if (!_tabCtrl!.indexIsChanging && mounted) setState(() {});
    });
    // Tool pode abrir depois do state push inicial: hidrata do cache.
    _state = RemoteSession.instance.lastState;
    _sub = RemoteSession.instance.states.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  // A pagina fica dentro de outro Scaffold, que consome o inset do teclado do
  // MediaQuery: por isso le direto da View.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final open = View.of(context).viewInsets.bottom > 0;
    if (open != _keyboardOpen) setState(() => _keyboardOpen = open);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabCtrl?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _openSelectedHymn(RemoteHymnSelection selection) {
    setState(() => _hymnSelection = null);
    RemoteSession.instance.send(
      RemoteCommand(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        action: RemoteAction.mediaOpen,
        musicId: selection.musicId,
        mode: selection.mode,
      ),
    );
  }

  void _openSelectedPlaylistTrack(RemotePlaylistSelection selection) {
    final lists = _state?.playlistModule?.lists ?? const <RemotePlaylist>[];
    RemotePlaylist? playlist;
    for (final list in lists) { if (list.id == selection.playlistId) playlist = list; }
    var index = selection.index;
    if (playlist == null) { setState(() => _playlistSelection = null); return; }
    if (index >= playlist.items.length || playlist.items[index].musicId != selection.musicId) {
      index = playlist.items.indexWhere((item) => item.musicId == selection.musicId);
    }
    setState(() => _playlistSelection = null);
    if (index < 0) return;
    RemoteSession.instance.send(RemoteCommand(
      id: 'pt${DateTime.now().microsecondsSinceEpoch}', action: RemoteAction.playlistTrack,
      targetId: selection.playlistId, index: index, mode: selection.mode,
    ));
  }

  /// Abre o dia no desktop; com liturgia, já mostra a lista espelhada.
  void _selectLiturgyDay(BuildContext context, RemoteLiturgyDay day) {
    RemoteSession.instance.send(
      RemoteCommand(
        id: 'd${DateTime.now().microsecondsSinceEpoch}',
        action: RemoteAction.liturgySelectDay,
        mode: day.key,
      ),
    );
    if (day.count > 0) _openLiturgy(context);
  }

  /// Abre a liturgia avulsa escolhida no desktop.
  void _selectLiturgyCustom(BuildContext context, RemoteLiturgyCustom custom) {
    RemoteSession.instance.send(
      RemoteCommand(
        id: 'c${DateTime.now().microsecondsSinceEpoch}',
        action: RemoteAction.liturgySelectCustom,
        index: custom.index,
      ),
    );
    if (custom.count > 0) _openLiturgy(context);
  }

  void _openLiturgy(BuildContext context) {
    // Liturgia do desktop: página própria do Controle Remoto. A Liturgia
    // nativa do apk (Ferramentas) segue local, sem relação com esta.
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RemoteLiturgyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = _state;
    // Conectado = controlando um alvo (desktop OU web link com browser).
    final connected = RemoteSession.instance.isControlling;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                key: const Key('tool-back'),
                icon: const Icon(TablerIcons.arrowLeft),
                onPressed: widget.onBack,
              ),
        title: Text('remote.title'.tr()),
        actions: [
          IconButton(
            key: const Key('remote-scan-qr'),
            tooltip: 'remote.scanQr'.tr(),
            icon: const Icon(TablerIcons.scan),
            // Lê o QR do DESKTOP (louvorja://connect?...) e conecta direto.
            onPressed: () async {
              final code = await Navigator.of(context).push<String>(
                MaterialPageRoute<String>(
                  builder: (_) => const DesktopQrScannerPage(),
                ),
              );
              if (code == null || !mounted) return;
              // apk#95: termos antes do conectar (aceitável e dispensável).
              final termsOk = await ensureTermsAccepted(this.context);
              if (!mounted) return;
              if (!termsOk) return;
              final uri = Uri.tryParse(code.trim());
              final host = uri?.queryParameters['host'];
              final token = uri?.queryParameters['token'];
              if (host == null || token == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('remote.qrInvalid'.tr())),
                );
                return;
              }
              final parts = host.split(':');
              await RemoteSession.instance.connectDesktop(
                host: parts.first,
                port: parts.length > 1 ? int.tryParse(parts[1]) ?? remoteDesktopDefaultPort : remoteDesktopDefaultPort,
                token: token,
              );
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'remote.disconnect'.tr(),
            icon: const Icon(TablerIcons.power),
            onPressed: () async {
              await RemoteSession.instance.disconnect();
              if (mounted) setState(() => _state = null);
            },
          ),
        ],
      ),
      body: !connected
          ? Center(child: Text('remote.connectFirst'.tr()))
          : st == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Abas v2: liturgia (padrão) + módulos do controle total.
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: false,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  labelStyle: theme.textTheme.bodySmall,
                  unselectedLabelStyle: theme.textTheme.bodySmall,
                  tabs: [
                    Tab(
                      icon: const Icon(TablerIcons.music),
                      text: 'remote.tabHymns'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.book),
                      text: 'remote.tabBible'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.clipboardText),
                      text: 'remote.tabLiturgy'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.playlist),
                      text: 'remote.tabPlaylist'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.layoutGrid),
                      text: 'remote.tabMore'.tr(),
                    ),
                  ],
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabCtrl?.index ?? 0,
                    children: [
                      RemoteHymnsPanel(
                        state: st,
                        selectedMusicId: _hymnSelection?.musicId,
                        onSelectionChanged: (s) =>
                            setState(() => _hymnSelection = s),
                      ),
                      TickerMode(
                        enabled: _tabCtrl?.index == 1,
                        child: RemoteBiblePanel(state: st),
                      ),
                      _liturgyStatus(context, theme, st),
                      RemotePlaylistPanel(state: st.playlistModule, selection: _playlistSelection, onSelectionChanged: (selection) => setState(() => _playlistSelection = selection)),
                      RemoteMorePanel(state: st),
                    ],
                  ),
                ),
                // Fixa no rodape; some com o teclado para nao espremer a
                // lista de resultados da busca de hinos.
                if (_playerTabs.contains(_tabCtrl?.index) && !_keyboardOpen)
                  RemotePlayerBar(
                    state: st,
                    showTransport: true,
                    pendingOpen: _tabCtrl?.index == 3
                        ? (_playlistSelection == null ? null : () => _openSelectedPlaylistTrack(_playlistSelection!))
                        : (_hymnSelection == null ? null : () => _openSelectedHymn(_hymnSelection!)),
                  ),
              ],
            ),
    );
  }

  // A liturgia espelhada vive no MÓDULO de Liturgia (mesma UI,
  // mesma personalização). Aqui só status + atalho.
  Widget _liturgyStatus(
    BuildContext context,
    ThemeData theme,
    RemotePlayerState st,
  ) {
    if (st.liturgyDays.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: RemoteLiturgyDays(
          days: st.liturgyDays,
          customs: st.liturgyCustoms,
          onSelect: (day) => _selectLiturgyDay(context, day),
          onSelectCustom: (custom) => _selectLiturgyCustom(context, custom),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Card(
        child: ListTile(
          key: const Key('remote-open-liturgy'),
          leading: Icon(
            TablerIcons.clipboardText,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            st.liturgyItems.isEmpty
                ? 'remote.noLiturgy'.tr()
                : 'remote.liturgyInLiturgyModule'.tr(
                    namedArgs: {'count': '${st.liturgyItems.length}'},
                  ),
          ),
          subtitle: st.liturgyItems.isEmpty
              ? null
              : Text('remote.openLiturgyModule'.tr()),
          trailing: const Icon(TablerIcons.chevronRight),
          onTap: st.liturgyItems.isEmpty ? null : () => _openLiturgy(context),
        ),
      ),
    );
  }
}
