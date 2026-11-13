import 'dart:convert';

/// Player do YouTube da Liturgia local, com as mesmas técnicas do desktop
/// (app: electron/youtube-source.mjs, youtube-embed.mjs e
/// youtube-ad-skip.mjs): embed oficial sem controles nem sugestões, Referer
/// de localhost e o script que pula o anúncio em vídeo dentro da página.
class YoutubeWeb {
  const YoutubeWeb._();

  static const _embedParams = {
    'autoplay': '1',
    'controls': '0',
    'rel': '0',
    'fs': '0',
    'iv_load_policy': '3',
    'disablekb': '1',
    'modestbranding': '1',
    'playsinline': '1',
  };

  static String embedUrl(String videoId) => Uri.https(
    'www.youtube.com',
    '/embed/${Uri.encodeComponent(videoId)}',
    _embedParams,
  ).toString();

  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=${Uri.encodeComponent(videoId)}';

  /// Erro 153: o embed exige um Referer válido; localhost evita o 152.
  static const headers = {'Referer': 'http://localhost/'};

  static const _video =
      "(document.querySelector('#movie_player video, .html5-video-player video') || document.querySelector('video'))";

  static const playScript =
      '(() => { const v = $_video; if (v) { const p = v.play(); if (p && p.catch) p.catch(() => {}); } })()';
  static const pauseScript =
      '(() => { const v = $_video; if (v) v.pause(); })()';

  static String seekScript(Duration position) {
    final seconds = position.inMilliseconds / 1000;
    return '(() => { const v = $_video; if (v) v.currentTime = $seconds; })()';
  }

  static String volumeScript(double volume) {
    final value = volume.clamp(0.0, 1.0);
    return '(() => { const v = $_video; if (!v) return; v.volume = $value; '
        'v.muted = ${value == 0 ? 'true' : 'false'}; })()';
  }

  /// Esconde só a camada de legenda selecionável do player, nunca texto
  /// gravado no vídeo (desktop: electron/youtube-captions.mjs).
  static String captionsScript(bool hidden) =>
      '''(() => {
  const hidden = $hidden;
  let style = document.getElementById('louvorja-youtube-captions');
  if (hidden && !style) {
    style = document.createElement('style');
    style.id = 'louvorja-youtube-captions';
    style.textContent = '#movie_player .ytp-caption-window-container, #movie_player .caption-window { display: none !important; visibility: hidden !important; }';
    (document.head || document.documentElement).appendChild(style);
  } else if (!hidden && style) style.remove();
  for (const video of document.querySelectorAll('video')) {
    for (const track of Array.from(video.textTracks || [])) track.mode = hidden ? 'hidden' : 'showing';
  }
  return true;
})()''';

  /// Estado lido a cada meio segundo. `ad` = anúncio na tela.
  static const probeScript =
      '''(() => {
  const v = $_video;
  const player = document.querySelector('#movie_player, .html5-video-player');
  const error = document.querySelector('.ytp-error');
  const ad = !!player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'));
  return JSON.stringify({
    playing: !!v && !v.paused && !v.ended,
    position: v ? (v.currentTime || 0) : 0,
    duration: v && isFinite(v.duration) ? v.duration : 0,
    ended: !!v && v.ended,
    error: !!error && error.getClientRects().length > 0,
    hasData: !!v && v.readyState >= 2,
    ad: ad,
  });
})()''';

  /// Mesmo script do desktop (youtube-ad-skip.mjs): enquanto o player está em
  /// anúncio o vídeo fica invisível e mudo, vai ao fim e o "Pular" é clicado.
  /// Sem filtros cosméticos globais, só os seletores do próprio player.
  static const adSkipScript = r'''(() => {
  const STYLE_ID = 'louvorja-yt-ad-skip';
  const CSS = [
    '.ad-showing video, .ad-interrupting video { opacity: 0 !important; }',
    '.ytp-ad-overlay-container, .ytp-ad-image-overlay, .ytp-ad-text-overlay,',
    '.ytp-ad-player-overlay, .ytp-ad-player-overlay-layout, .ytp-ad-module,',
    '#player-ads, #masthead-ad, ytd-ad-slot-renderer, ytd-display-ad-renderer,',
    'ytd-companion-slot-renderer, ytd-action-companion-ad-renderer,',
    'ytd-promoted-sparkles-web-renderer, ytd-in-feed-ad-layout-renderer,',
    '.ytp-pause-overlay, .ytp-chrome-top, .ytp-watermark',
    '{ display: none !important; }',
  ].join('\n');
  const SKIP_BUTTONS = [
    '.ytp-skip-ad-button',
    '.ytp-ad-skip-button',
    '.ytp-ad-skip-button-modern',
    '.ytp-ad-skip-button-slot button',
    '.videoAdUiSkipButton',
  ].join(', ');
  // Ao minimizar a WebView sai da tela e o YouTube pausaria por estar
  // "oculto": a página sempre se vê visível.
  if (!window.__louvorjaAlwaysVisible) {
    window.__louvorjaAlwaysVisible = true;
    try {
      Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
      Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
    } catch (e) {}
    const block = (event) => event.stopImmediatePropagation();
    document.addEventListener('visibilitychange', block, true);
    window.addEventListener('pagehide', block, true);
    window.addEventListener('blur', block, true);
  }
  const state = window.__louvorjaYtAdSkip || (window.__louvorjaYtAdSkip = { saved: null, timer: null, observer: null, observed: null });
  const findPlayer = () => {
    const player = document.querySelector('#movie_player, .html5-video-player');
    return { player, video: player ? player.querySelector('video') : null };
  };
  const restore = (video) => {
    if (state.saved && video) {
      video.muted = state.saved.muted;
      video.playbackRate = state.saved.playbackRate;
    }
    state.saved = null;
  };
  state.tick = () => {
    const { player, video } = findPlayer();
    if (!player || !video) return;
    if (state.observer && state.observed !== player) {
      state.observer.observe(player, { attributes: true, attributeFilter: ['class'] });
      state.observed = player;
    }
    const inAd = player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting');
    if (!inAd) { restore(video); return; }
    if (!state.saved) state.saved = { muted: video.muted, playbackRate: video.playbackRate };
    video.muted = true;
    try { video.playbackRate = 16; } catch (e) {}
    const duration = video.duration;
    if (Number.isFinite(duration) && duration > 0 && video.currentTime < duration) {
      video.currentTime = duration;
    }
    document.querySelectorAll(SKIP_BUTTONS).forEach((button) => button.click());
  };
  if (!document.getElementById(STYLE_ID)) {
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = CSS;
    (document.head || document.documentElement).appendChild(style);
  }
  if (!state.observer) state.observer = new MutationObserver(() => state.tick());
  if (!state.timer) state.timer = setInterval(() => state.tick(), 250);
  state.tick();
  return true;
})()''';
}

class YoutubeWebState {
  const YoutubeWebState({
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.ended = false,
    this.error = false,
    this.hasData = false,
    this.ad = false,
  });
  final bool playing, ended, error, hasData, ad;
  final Duration position, duration;

  /// O Android devolve o JSON entre aspas (string de string).
  static YoutubeWebState? parse(Object? raw) {
    Object? value = raw;
    try {
      for (var i = 0; i < 2 && value is String; i++) {
        value = jsonDecode(value);
      }
    } catch (_) {
      return null;
    }
    if (value is! Map) return null;
    Duration seconds(Object? v) =>
        Duration(milliseconds: ((v is num ? v : 0) * 1000).round());
    return YoutubeWebState(
      playing: value['playing'] == true,
      position: seconds(value['position']),
      duration: seconds(value['duration']),
      ended: value['ended'] == true,
      error: value['error'] == true,
      hasData: value['hasData'] == true,
      ad: value['ad'] == true,
    );
  }
}
