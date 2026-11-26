import 'package:flutter/foundation.dart';

import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';

/// Histórico e favoritos do YouTube do desktop, como chegaram no estado.
///
/// O desktop manda as listas só quando mudam (ou ao conectar); nos outros
/// estados vem só a chave. Por isso ficam guardadas aqui, pela sessão.
class RemoteYoutubeLibrary {
  RemoteYoutubeLibrary._();

  static String? _key;
  static List<Object?> _history = const [];
  static List<Object?> _favorites = const [];

  /// Muda a cada lista nova (do desktop ou da mudança feita no celular).
  static final changes = ValueNotifier<int>(0);

  static List<Object?> get history => _history;
  static List<Object?> get favorites => _favorites;

  /// Guarda as listas que vierem no estado.
  static void remember(RemotePlayerState state) {
    final history = state.youtubeHistory;
    final favorites = state.youtubeFavorites;
    if (history == null && favorites == null) return;
    _key = state.youtubeLibraryKey;
    if (history != null) _history = List.unmodifiable(history);
    if (favorites != null) _favorites = List.unmodifiable(favorites);
    changes.value++;
  }

  /// Mudança feita no celular, mostrada já, até o desktop mandar a lista dele.
  static void applyLocal({List<Object?>? history, List<Object?>? favorites}) {
    if (history != null) _history = List.unmodifiable(history);
    if (favorites != null) _favorites = List.unmodifiable(favorites);
    changes.value++;
  }

  static String? get key => _key;

  @visibleForTesting
  static void reset() {
    _key = null;
    _history = const [];
    _favorites = const [];
  }
}
