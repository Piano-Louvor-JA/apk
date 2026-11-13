import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

/// Miniaturas da galeria aberta no desktop.
///
/// O desktop manda todas uma vez só (ao abrir a galeria ou ao conectar), e
/// nessa hora a barra do player pode nem estar na tela: por isso ficam aqui,
/// guardadas pela sessão, e não na barra.
class RemoteSlideGallery {
  RemoteSlideGallery._();

  static String? _key;
  static List<Uint8List?> _thumbs = const [];

  // Fundos dos slides do hino: bytes (miniatura) ou endereço para baixar.
  static final _backgroundSets = <String, List<Object?>>{};

  /// Guarda as miniaturas que vierem no estado.
  static void remember(RemotePlayerState state) {
    _rememberBackgrounds(state);
    final key = state.slideGalleryKey;
    final previews = state.slidePreviews;
    if (key == null || previews == null) return;
    if (key == _key && previews.length == _thumbs.length) return;
    _key = key;
    _thumbs = [for (final p in previews) decode(p)];
  }

  /// Miniatura da imagem [index] da galeria [key], se já chegou.
  static Uint8List? thumb(String? key, int index) {
    if (key == null || key != _key) return null;
    if (index < 0 || index >= _thumbs.length) return null;
    return _thumbs[index];
  }

  static void _rememberBackgrounds(RemotePlayerState state) {
    final key = state.slideBackgroundKey;
    final sources = state.slideBackgroundSources;
    if (key == null || sources == null) return;
    if (_backgroundSets[key]?.length == sources.length) return;
    // Limite de memória: conjuntos recentes dos players local e remoto.
    if (_backgroundSets.length >= 4)
      _backgroundSets.remove(_backgroundSets.keys.first);
    _backgroundSets[key] = [
      for (final source in sources)
        if (source.startsWith('data:'))
          decode(source.substring(source.indexOf(',') + 1))
        else if (source.startsWith('http'))
          source
        else
          null,
    ];
  }

  /// Fundo do slide [index]: `Uint8List`, endereço (`String`) ou null.
  static Object? background(RemotePlayerState state, int index) {
    final positions = state.slideBackgroundIndex;
    final backgrounds = _backgroundSets[state.slideBackgroundKey];
    if (backgrounds == null ||
        positions == null ||
        index < 0 ||
        index >= positions.length) {
      return null;
    }
    final at = positions[index];
    if (at < 0 || at >= backgrounds.length) return null;
    return backgrounds[at];
  }

  static Uint8List? decode(String source) {
    if (source.isEmpty) return null;
    try {
      return base64Decode(source);
    } on FormatException {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    _key = null;
    _thumbs = const [];
    _backgroundSets.clear();
  }
}
