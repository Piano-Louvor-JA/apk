library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/datasources/local/playlist_storage.dart';
import '../../domain/entities/hymn.dart';
import '../../presentation/hymns/now_playing_page.dart';
import '../constants/api_config.dart';
import 'download_url_builder.dart';
import 'hymn_audio_player.dart';
import 'hymn_catalog_access.dart';
import 'hymn_player_adapter.dart';
import 'now_playing.dart';

/// Toca uma playlist inteira (em ordem ou aleatória), como o desktop:
/// ao terminar um hino passa para o próximo; a tela "Tocando agora"
/// acompanha a faixa atual.
class PlaylistPlayer {
  PlaylistPlayer._();
  static final instance = PlaylistPlayer._();

  List<PlaylistItem> _queue = const [];
  int _index = -1;
  String _language = 'pt';
  NavigatorState? _navigator;
  /// Tela "Tocando agora" aberta pela playlist (null = fechada).
  Route<void>? _route;
  StreamSubscription<void>? _completion;

  bool get active => _index >= 0 && _index < _queue.length;

  Future<void> play(
    BuildContext context,
    Playlist playlist, {
    bool shuffle = false,
    int startAt = 0,
  }) async {
    if (playlist.items.isEmpty) return;
    final items = [...playlist.items];
    if (shuffle) items.shuffle(Random());
    _queue = items;
    _index = shuffle ? 0 : startAt.clamp(0, items.length - 1);
    _language = Localizations.localeOf(context).languageCode == 'es'
        ? 'es'
        : 'pt';
    _navigator = Navigator.of(context);
    await _completion?.cancel();
    _completion = HymnAudioPlayer.instance.completionStream.listen(
      (_) => _next(),
    );
    // Igual à busca de Hinos: só toca; a letra fica na prévia do
    // miniplayer (tela cheia pelo botão de tela cheia).
    await _playCurrent(openPage: false);
  }

  bool get canPrevious => active && _index > 0;
  bool get canNext => active && _index < _queue.length - 1;

  /// Anterior/próxima pelo miniplayer.
  Future<void> previous() async {
    if (!canPrevious) return;
    _index -= 1;
    await _playCurrent(openPage: false);
  }

  Future<void> next() async {
    if (!canNext) return;
    _index += 1;
    await _playCurrent(openPage: false);
  }

  /// "Adicionar à fila": põe as faixas no fim da fila em execução.
  /// Devolve false quando não há fila tocando (quem chamou decide tocar).
  bool append(List<PlaylistItem> items) {
    if (!active || items.isEmpty) return false;
    _queue = [..._queue, ...items];
    return true;
  }

  void stop() {
    _completion?.cancel();
    _completion = null;
    _queue = const [];
    _index = -1;
  }

  Future<void> _next() async {
    if (!active) return;
    // Outro hino foi tocado fora da playlist: a playlist para.
    if (nowPlaying.track?.hymnId != _queue[_index].musicId) {
      stop();
      return;
    }
    await _advance();
  }

  /// Próxima faixa (também usado para pular hino indisponível).
  Future<void> _advance() async {
    _index += 1;
    if (!active) {
      stop();
      return;
    }
    await _playCurrent(openPage: false);
  }

  Future<void> _playCurrent({required bool openPage}) async {
    final item = _queue[_index];
    final Hymn detail;
    try {
      final repo = await HymnCatalogAccess.repository(_language);
      detail = await repo.getHymnDetails(item.musicId);
    } catch (_) {
      // Hino indisponível (sem rede e não baixado): pula para o próximo.
      unawaited(_advance());
      return;
    }
    final url = detail.urlMusic ?? '';
    if (url.isEmpty) {
      unawaited(_advance());
      return;
    }
    final source = DownloadUrlBuilder.build(url);
    final player = HymnAudioPlayer.instance;
    nowPlaying.start(
      hymnId: item.musicId,
      title: detail.title ?? item.title,
      album: '',
      albumId: item.albumId ?? 0,
      durationMs: detail.durationMs,
      detail: detail,
      audioSource: source,
    );
    await player.playUrl(source);

    final navigator = _navigator;
    if (navigator == null || !navigator.mounted) return;
    final page = MaterialPageRoute<void>(
      builder: (_) => NowPlayingPage(
        detail: detail,
        instrumental: false,
        player: HymnPlayerAdapter(player),
        filesUrl: ApiConfig.urlFiles,
      ),
    );
    if (!openPage && _route == null) return;
    final previous = _route;
    // Se a pessoa foi para outra tela, só troca o áudio (não mexe na pilha).
    if (previous != null && !previous.isCurrent) return;
    _route = page;
    // Só limpa se ainda for a tela atual (troca de faixa também completa
    // o future da tela anterior).
    void closed(void _) {
      if (_route == page) _route = null;
    }
    if (previous == null) {
      unawaited(navigator.push(page).then(closed));
    } else {
      unawaited(navigator.pushReplacement(page).then(closed));
    }
  }
}
