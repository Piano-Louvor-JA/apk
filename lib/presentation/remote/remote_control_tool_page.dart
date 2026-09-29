// coverage:ignore-file
// UI de controle remoto (ferramenta) — widget tree + sessão WS, sem teste unit
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';
import 'package:louvorja_piano_mobile/presentation/remote/remote_module_panels.dart';
import 'package:louvorja_piano_mobile/presentation/settings/widgets/remote/remote_section.dart';

import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_session.dart';

/// Ferramenta "Controle Remoto": visível quando há sessão conectada.
/// Layout de controle remoto — liturgia espelhada + controles de mídia.
class RemoteControlToolPage extends StatefulWidget {
  const RemoteControlToolPage({super.key});

  @override
  State<RemoteControlToolPage> createState() => _RemoteControlToolPageState();
}

class _RemoteControlToolPageState extends State<RemoteControlToolPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  RemotePlayerState? _state;
  double? _dragVolume;
  TabController? _tabCtrl;

  @override
  void initState() {
    super.initState();
    // TabBar exige controller (sem ele lança e a view fica cinza).
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl!.addListener(() {
      if (!_tabCtrl!.indexIsChanging && mounted) setState(() {});
    });
    // Tool pode abrir depois do state push inicial: hidrata do cache.
    _state = RemoteSession.instance.lastState;
    _sub = RemoteSession.instance.states.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _send(RemoteAction action, {int? index, int? volume}) async {
    await RemoteSession.instance.send(
      RemoteCommand(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        action: action,
        index: index,
        volume: volume,
      ),
    );
  }

  void _openLiturgy(BuildContext context) {
    // Liturgia espelhada: módulo de Liturgia, não o controle remoto.
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LiturgyPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = _state;
    // Conectado = controlando um alvo (desktop OU web link com browser).
    final connected = RemoteSession.instance.isControlling;

    return Scaffold(
      appBar: AppBar(
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
              if (code == null) return;
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
                port: parts.length > 1 ? int.tryParse(parts[1]) ?? 7071 : 7071,
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
                  isScrollable: true,
                  tabs: [
                    Tab(
                      icon: const Icon(TablerIcons.clipboardText),
                      text: 'remote.tabLiturgy'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.music),
                      text: 'remote.tabHymns'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.book),
                      text: 'remote.tabBible'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.clock),
                      text: 'remote.tabTime'.tr(),
                    ),
                    Tab(
                      icon: const Icon(TablerIcons.dice),
                      text: 'remote.tabMore'.tr(),
                    ),
                  ],
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabCtrl?.index ?? 0,
                    children: [
                      // aba 0: status liturgia + player (conteúdo original)
                      _liturgyAndPlayer(context, theme, st),
                      RemoteHymnsPanel(state: st),
                      RemoteBiblePanel(state: st),
                      RemoteTimePanel(state: st),
                      RemoteClockRandomPanel(
                        clock: st.clockModule,
                        random: st.randomModule,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _liturgyAndPlayer(
    BuildContext context,
    ThemeData theme,
    RemotePlayerState st,
  ) {
    return Column(
      children: [
        // A liturgia espelhada vive no MÓDULO de Liturgia (mesma UI,
        // mesma personalização). Aqui só status + atalho.
        Padding(
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
              onTap: st.liturgyItems.isEmpty
                  ? null
                  : () => _openLiturgy(context),
            ),
          ),
        ),
        // Controles de mídia — visual de controle remoto
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (st.title != null)
                    Text(
                      st.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'remote.previous'.tr(),
                        onPressed: st.canPrevious
                            ? () => _send(RemoteAction.previous)
                            : null,
                        icon: const Icon(TablerIcons.playerSkipBack),
                      ),
                      IconButton.filled(
                        iconSize: 36,
                        tooltip: st.playing
                            ? 'remote.pause'.tr()
                            : 'remote.play'.tr(),
                        onPressed: () => _send(
                          st.playing ? RemoteAction.pause : RemoteAction.play,
                        ),
                        icon: Icon(
                          st.playing
                              ? TablerIcons.playerPause
                              : TablerIcons.playerPlay,
                        ),
                      ),
                      IconButton(
                        tooltip: 'remote.next'.tr(),
                        onPressed: st.canNext
                            ? () => _send(RemoteAction.next)
                            : null,
                        icon: const Icon(TablerIcons.playerSkipForward),
                      ),
                      IconButton(
                        tooltip: 'remote.stop'.tr(),
                        onPressed: () => _send(RemoteAction.stop),
                        icon: const Icon(TablerIcons.playerStop),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    children: [
                      const Icon(TablerIcons.volume, size: 18),
                      Expanded(
                        child: Slider(
                          value:
                              _dragVolume ??
                              (st.volume).clamp(0, 100).toDouble(),
                          max: 100,
                          // Só envia ao soltar: evita flood WS no drag.
                          onChanged: (v) => setState(() => _dragVolume = v),
                          onChangeEnd: (v) async {
                            await _send(
                              RemoteAction.setVolume,
                              volume: v.round(),
                            );
                            if (mounted) {
                              setState(() => _dragVolume = null);
                            }
                          },
                        ),
                      ),
                      const Icon(TablerIcons.volume2, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
