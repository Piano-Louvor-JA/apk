import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/repositories/local_liturgy_media.dart';

const emptyLocalPlayer = RemotePlayerState(
  playing: false,
  position: Duration.zero,
  duration: Duration.zero,
  slideIndex: 0,
  slideCount: 0,
  volume: 100,
  canPrevious: false,
  canNext: false,
);

/// Seleção não executa conteúdo. O player sobrevive à rota da liturgia.
class LocalLiturgyPlayer extends Cubit<RemotePlayerState> {
  LocalLiturgyPlayer(this.media) : super(emptyLocalPlayer) {
    _subscription = media.states.listen((value) {
      if (!isClosed && _acceptStates) emit(value);
    });
  }
  final LocalLiturgyMedia media;
  late final StreamSubscription<RemotePlayerState> _subscription;
  LiturgyItem? pending;
  LiturgyItem? active;
  String _language = 'pt';
  DateTime _date = DateTime.now();
  bool busy = false;
  bool _acceptStates = true;
  int _generation = 0;
  void Function(LiturgyItem)? onStarted;
  void Function(LiturgyItem)? onChanged;
  Future<void> Function()? _externalOpen;

  void choose(
    LiturgyItem item, {
    required String language,
    required DateTime date,
    void Function(LiturgyItem)? onStarted,
    void Function(LiturgyItem)? onChanged,
    Future<void> Function()? externalOpen,
  }) {
    if (state.hasOpenMedia || busy) return;
    pending = item;
    _language = language;
    _date = date;
    this.onStarted = onStarted;
    this.onChanged = onChanged;
    _externalOpen = externalOpen;
    // Nova instância para notificar também uma troca de seleção pendente.
    emit(
      RemotePlayerState(
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        slideIndex: 0,
        slideCount: 0,
        volume: state.volume,
        canPrevious: false,
        canNext: false,
      ),
    );
  }

  Future<void> openPending() async {
    final item = pending;
    if (item == null || busy || state.hasOpenMedia) return;
    busy = true;
    _acceptStates = true;
    final generation = ++_generation;
    _notify();
    try {
      final external = _externalOpen;
      if (external != null) {
        await external();
      } else {
        await media.open(item, _language, _date);
      }
      if (generation != _generation || isClosed) return;
      active = external == null ? item : null;
      pending = null;
      onStarted?.call(item);
    } catch (_) {
      if (generation != _generation || isClosed) return;
      await media.send(
        RemoteCommand(id: 'local-open-failed', action: RemoteAction.stop),
      );
      rethrow;
    } finally {
      if (generation == _generation && !isClosed) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> send(RemoteCommand command) async {
    if (command.action == RemoteAction.stop) {
      ++_generation;
      _acceptStates = false;
      busy = false;
    }
    await media.send(command);
    if (command.action == RemoteAction.stop) {
      active = null;
      pending = null;
      onStarted = null;
      onChanged = null;
      _externalOpen = null;
      emit(emptyLocalPlayer);
    }
  }

  Future<void> updateText(LiturgyItem changed) async {
    if (active?.id != changed.id || onChanged == null) return;
    await media.updateText(changed);
    active = changed;
    onChanged?.call(changed);
  }

  void _notify() {
    if (isClosed) return;
    final value = state;
    emit(
      RemotePlayerState(
        title: value.title,
        hymnId: value.hymnId,
        mode: value.mode,
        playing: value.playing,
        position: value.position,
        duration: value.duration,
        slideIndex: value.slideIndex,
        slideCount: value.slideCount,
        volume: value.volume,
        canPrevious: value.canPrevious,
        canNext: value.canNext,
        slidePreview: value.slidePreview,
        slideLyrics: value.slideLyrics,
        slideGalleryKey: value.slideGalleryKey,
        slidePreviews: value.slidePreviews,
        slideBackgroundKey: value.slideBackgroundKey,
        slideBackgroundIndex: value.slideBackgroundIndex,
        slideBackgroundSources: value.slideBackgroundSources,
        videoControls: value.videoControls,
      ),
    );
  }

  @override
  Future<void> close() async {
    ++_generation;
    _acceptStates = false;
    await _subscription.cancel();
    await media.dispose();
    return super.close();
  }
}
