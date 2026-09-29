library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';

import '../../../../core/services/hymn_audio_player.dart';
import '../../../../core/services/hymn_player_adapter.dart';
import '../../../../core/services/now_playing.dart';
import 'mini_player_bar.dart';
import '../../hymns/now_playing_page.dart';

/// MainNavigation — bottom navigation com 5 tabs.
///
/// Fonte: pianolouvorja/app/src/shared/constants/navigation.ts
/// + DockFooter.vue
///
/// Tabs: Início, Hinos, Liturgia, Bíblia, Mais.
/// Tab ativa: icone + label na cor primary, sem fundo.
/// Tabs inativas: icone + label em cinza (onSurfaceVariant).
final _miniPlayerAdapter = HymnPlayerAdapter(HymnAudioPlayer.instance);

class MainNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigation({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = navigationShell.currentIndex;

    final tabs = [
      _NavTab(icon: TablerIcons.home, label: 'nav.home'.tr()),
      _NavTab(icon: TablerIcons.playlist, label: 'nav.hymns'.tr()),
      _NavTab(icon: TablerIcons.tools, label: 'nav.tools'.tr()),
      _NavTab(icon: TablerIcons.settings, label: 'nav.more'.tr()),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayerBar(
            notifier: nowPlaying,
            player: _miniPlayerAdapter,
            // Tap no mini = REABRIR o NowPlaying da faixa em execução
            // (antes navegava pra aba Hinos — bug multi-palco 2026-08-21).
            onOpenPlayer: () {
              final track = nowPlaying.track;
              final detail = track?.detail;
              if (detail == null) {
                _onTap(1); // sem detail (faixa antiga): fallback pra Hinos
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NowPlayingPage(
                    detail: detail,
                    instrumental: track?.instrumental ?? false,
                    albumCoverUrl: track?.albumCoverUrl,
                    player: _miniPlayerAdapter,
                    filesUrl: ApiConfig.urlFiles,
                    audioSource: track?.audioSource,
                    audioIsLocal: track?.audioIsLocal ?? false,
                  ),
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outline, width: 1),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 60,
                child: Row(
                  children: List.generate(tabs.length, (i) {
                    final tab = tabs[i];
                    final isSelected = i == currentIndex;
                    final color = isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onTap(i),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.icon, size: 24, color: color),
                              const SizedBox(height: 4),
                              Text(
                                tab.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;

  _NavTab({required this.icon, required this.label});
}
