import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:louvorja_piano_mobile/core/constants/api_config.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_service.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_pdf_document.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_playback.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_video_cache.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_web_target.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/rich_notes.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/scheduled_resolver.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_models.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_slot.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_orchestrator.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/utils/media_image_url.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/domain/entities/lyric_slides.dart';
import 'package:louvorja_piano_mobile/domain/repositories/local_liturgy_media.dart';
import 'liturgy_catalog_repository.dart';
import 'liturgy_link_repository_impl.dart';
import 'scheduled_repository.dart';

/// Recursos nativos permanecem abertos quando a barra é minimizada.
/// Nunca envia comandos à sessão de controle remoto.
class LocalLiturgyMediaImpl implements LocalLiturgyMedia {
  final _states = StreamController<RemotePlayerState>.broadcast(sync: true);
  @override
  Stream<RemotePlayerState> get states => _states.stream;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  LiturgyItem? item;
  VideoPlayerController? video;
  HymnAudioPlayer? _audio;
  String? _source;
  LyricSlides _lyrics = LyricSlides.empty;
  List<String> _backgrounds = [];
  List<String> _paths = [];
  LiturgyPdfDocument? _pdf;
  Uint8List? _preview;
  int _slide = 0, _count = 0, _volume = 100;
  Duration _position = Duration.zero, _duration = Duration.zero;
  bool _playing = false, _projecting = false, _captionsHidden = false;
  int _generation = 0;
  bool _disposed = false;
  String _language = 'pt';
  DateTime _date = DateTime.now();
  String _output = 'player';
  String _independentMode = 'overlay';
  final _independent = <String>{};
  final _previousMuted = <String, bool>{};
  final _projected = <String>{};
  List<PalcoSlot> get _targets => _palco.slots
      .where(
        (s) =>
            s.isConnected &&
            (!_palco.isMuted(s.id) || _independent.contains(s.id)),
      )
      .toList();
  List<RemoteVideoTarget> get _independentTargets => _palco.slots
      .where((s) => s.isConnected)
      .map(
        (s) => RemoteVideoTarget(
          id: s.id,
          label: s.label,
          selected: _independent.contains(s.id),
          enabled: !(_previousMuted[s.id] ?? _palco.isMuted(s.id)),
          onAir: _projected.contains(s.id) && _independent.contains(s.id),
        ),
      )
      .toList();
  StageSession get _stage => StageSession.instance;
  PalcoOrchestrator get _palco => PalcoOrchestrator.instance;

  final VideoPlayerController Function(String)? _createVideo;
  final HymnAudioPlayer? _audioOverride;
  final Future<LiturgyMusicPlayback> Function(LiturgyItem, String)?
  _resolveMusic;
  LocalLiturgyMediaImpl({
    HymnAudioPlayer? audio,
    VideoPlayerController Function(String)? createVideo,
    Future<LiturgyMusicPlayback> Function(LiturgyItem, String)? resolveMusic,
  }) : _audioOverride = audio,
       _resolveMusic = resolveMusic,
       _createVideo = createVideo {
    nowPlaying.addListener(_legacyChanged);
    _stage.addListener(_emit);
    _palco.addListener(_emit);
  }

  void _legacyChanged() {
    if (item != null && nowPlaying.track != null) {
      ++_generation;
      unawaited(_release(stopAudio: false));
    }
  }

  RemotePlayerState get snapshot => RemotePlayerState(
    hymnId: item?.musicId,
    title: item?.name,
    mode: item?.musicMode,
    playing: _playing,
    position: _position,
    duration: _duration,
    slideIndex: _slide,
    slideCount: _count,
    volume: _volume,
    canPrevious: false,
    canNext: false,
    slidePreview: _preview == null ? null : base64Encode(_preview!),
    slideLyrics: _lyrics.slides.isNotEmpty
        ? _lyrics.slides.map((s) => s.text).toList()
        : (item == null || video != null || _count > 0 ? null : [item!.name]),
    slideBackgroundKey: _lyrics.slides.isEmpty
        ? null
        : 'local-${item?.id}-${item?.musicMode}',
    slideBackgroundSources: _backgrounds,
    slideBackgroundIndex: List.generate(_backgrounds.length, (i) => i),
    videoControls: item == null
        ? null
        : RemoteVideoControls(
            audioOutput: _output,
            canProject: _stage.isOn || _palco.anyConnected,
            projecting: _projecting,
            canControlCaptions: _lyrics.slides.isNotEmpty,
            captionsHidden: _captionsHidden,
            monitors: const [],
            independent: RemoteIndependentControls(
              mode: _independentMode,
              live: _projecting && _independent.isNotEmpty,
              armed: !_projecting && _independent.isNotEmpty,
              monitors: const [],
              remotes: _independentTargets,
            ),
            tvs: _palco.slots
                .where((s) => s.isConnected)
                .map(
                  (s) => RemoteVideoTarget(
                    id: s.id,
                    label: s.label,
                    selected: !_palco.isMuted(s.id),
                  ),
                )
                .toList(),
          ),
  );
  void _emit() {
    if (!_disposed) _states.add(snapshot);
  }

  @override
  Future<void> open(LiturgyItem requested, String language, DateTime date) =>
      _open(requested, language, date);

  /// [keepProjection] mantém as TVs projetando ao reabrir o mesmo item, como
  /// a troca de modo do desktop, que preserva a sessão.
  Future<void> _open(
    LiturgyItem requested,
    String language,
    DateTime date, {
    bool keepProjection = false,
  }) async {
    await _release(keepProjection: keepProjection);
    final generation = ++_generation;
    if (nowPlaying.track != null) {
      await (_audioOverride ?? HymnAudioPlayer.instance).stop();
      nowPlaying.stop();
    }
    _language = language;
    _date = date;
    var selected = requested;
    if (selected.type == LiturgyItemType.scheduled) {
      final repo = ScheduledRepository(await SharedPreferences.getInstance());
      final resolved = ScheduledResolver.resolve(
        selected,
        date,
        repo.loadCategories(),
        repo.loadItems(),
      );
      if (resolved == null) throw StateError('liturgy.parity.scheduledEmpty');
      selected = resolved;
    }
    item = selected;
    if (selected.type == LiturgyItemType.music) {
      final playback = _resolveMusic != null
          ? await _resolveMusic(selected, language)
          : await LiturgyPlayback.resolve(
              selected,
              catalog: await LiturgyCatalogRepository.open(language),
              offline: OfflineMusicService(),
            );
      if (generation != _generation) return;
      _source = playback.source;
      _duration = Duration(
        milliseconds: playback.detail.durationMs ?? selected.durationMs,
      );
      _lyrics = LyricSlides.fromApi(
        musicName: playback.detail.title ?? selected.name,
        coverUrl: playback.detail.imageUrl,
        raw: playback.detail.lyricRaw ?? const [],
      );
      final backgrounds = await Future.wait(
        _lyrics.slides.map((s) async {
          final raw = s.imageUrl;
          if (raw == null || raw.isEmpty) return '';
          final url = MediaImageUrl.resolve(raw, ApiConfig.urlFiles);
          if (!url.startsWith('asset:')) return url;
          final data = await rootBundle.load(url.substring(6));
          return 'data:image/jpeg;base64,${base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))}';
        }),
      );
      if (generation != _generation) return;
      _backgrounds = backgrounds;
      _count = _lyrics.slides.length;
      nowPlaying.stop();
      final audio = _audio = _audioOverride ?? HymnAudioPlayer.instance;
      _subscriptions.add(
        audio.positionStream.listen((value) {
          _position = value;
          final next = _lyrics.indexAt(
            value,
            instrumental: item?.musicMode == 'instrumental',
          );
          if (next != _slide) {
            _slide = next;
            if (_projecting) unawaited(_project());
          }
          _emit();
        }),
      );
      _subscriptions.add(
        audio.durationStream.listen((value) {
          if (value > Duration.zero) _duration = value;
          _emit();
        }),
      );
      _subscriptions.add(
        audio.playingStream.listen((value) {
          if (audio.currentUrl != _source && audio.currentUrl != null) {
            unawaited(_release(stopAudio: false));
            return;
          }
          _playing = value;
          _emit();
        }),
      );
      await audio.setVolume(_volume / 100);
      await audio.playUrl(playback.source);
      _playing = true;
    } else if ({
      LiturgyItemType.video,
      LiturgyItemType.onlineVideo,
      LiturgyItemType.audio,
    }.contains(selected.type)) {
      var source =
          selected.filePath ??
          selected.filePaths.firstOrNull ??
          selected.url ??
          '';
      if (selected.type == LiturgyItemType.onlineVideo) {
        final target = LiturgyWebTarget.parse(source);
        if (target == null) throw StateError('liturgy.parity.incompleteItem');
        final cache = LiturgyVideoCache(
          Directory(
            '${(await getApplicationSupportDirectory()).path}/liturgy-videos',
          ),
          LiturgyLinkRepositoryImpl(),
        );
        source =
            await cache.find(target.url) ?? await cache.download(target.url);
      }
      if (generation != _generation) return;
      _source = source;
      final uri = Uri.tryParse(source);
      final controller = video = _createVideo != null
          ? _createVideo(source)
          : (uri?.scheme == 'https' || uri?.scheme == 'http')
          ? VideoPlayerController.networkUrl(uri!)
          : VideoPlayerController.file(File(source));
      await controller.initialize();
      if (generation != _generation) return;
      controller.addListener(_videoChanged);
      await controller.setVolume(_volume / 100);
      await controller.play();
      _videoChanged();
    } else if (selected.type == LiturgyItemType.pdf) {
      final path = selected.filePath ?? selected.filePaths.firstOrNull;
      if (path == null) throw StateError('liturgy.parity.fileUnavailable');
      final pdf = LiturgyPdfDocument(path);
      final count = await pdf.pageCount();
      if (generation != _generation) return;
      if (count < 1) throw StateError('liturgy.parity.fileUnavailable');
      final preview = await pdf.render(0, width: 960);
      if (generation != _generation) return;
      _pdf = pdf;
      _count = count;
      _preview = preview;
    } else if (selected.type == LiturgyItemType.images) {
      final paths = selected.filePaths.isNotEmpty
          ? selected.filePaths
          : [if (selected.filePath != null) selected.filePath!];
      if (paths.isEmpty) throw StateError('liturgy.parity.fileUnavailable');
      final preview = await File(paths.first).readAsBytes();
      if (generation != _generation) return;
      _paths = paths;
      _count = paths.length;
      _preview = preview;
    } else if (!{
      LiturgyItemType.annotation,
      LiturgyItemType.notice,
      LiturgyItemType.prayer,
    }.contains(selected.type)) {
      throw StateError('liturgy.parity.fileUnavailable');
    }
    if (generation == _generation) _emit();
  }

  void _videoChanged() {
    final value = video?.value;
    if (value == null) return;
    _playing = value.isPlaying;
    _position = value.position;
    _duration = value.duration;
    _emit();
  }

  Future<void> _slideTo(int index) async {
    if (_count == 0) return;
    final next = index.clamp(0, _count - 1);
    final generation = _generation;
    final bytes = _pdf != null
        ? await _pdf!.render(next, width: 960)
        : _paths.isNotEmpty
        ? await File(_paths[next]).readAsBytes()
        : null;
    if (generation != _generation) return;
    _slide = next;
    _preview = bytes;
    if (_lyrics.slides.isNotEmpty) {
      final lyric = _lyrics.slides[next];
      final time = item?.musicMode == 'instrumental'
          ? lyric.instrumentalTime
          : lyric.time;
      if (time != null) await _audio?.seek(time);
    }
    if (_projecting) await _project();
    _emit();
  }

  String? _address(PalcoController controller, String? source) {
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:')) {
      return controller.serveMedia(
        'liturgy-background-$_slide.jpg',
        base64Decode(source.substring(source.indexOf(',') + 1)),
      );
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return controller.proxyUrl(source);
    }
    final file = File(source);
    if (!file.existsSync()) return null;
    return controller.serveMedia(
      'liturgy-${file.uri.pathSegments.last}',
      file.readAsBytesSync(),
    );
  }

  void _sendToSlot(PalcoSlot slot, PalcoMessage message) =>
      slot.controller.sendLiturgyMessage(
        message,
        share: _independent.contains(slot.id) && _independentMode == 'share',
      );
  void _sendLive(PalcoMessage message) {
    for (final slot in _palco.slots.where(
      (s) => s.isConnected && _projected.contains(s.id),
    )) {
      _sendToSlot(slot, message);
    }
  }

  Future<void> _project() async {
    final selected = item;
    if (selected == null) return;
    if (_palco.anyConnected) {
      final targets = _targets;
      final current = targets.map((s) => s.id).toSet();
      for (final id in _projected.difference(current)) {
        final slot = _palco.slot(id);
        if (slot != null) {
          _sendToSlot(slot, const PalcoMessage(type: 'idle'));
          slot.controller.setLiturgyShare(false);
        }
      }
      _projected.removeWhere((id) => !current.contains(id));
      final added = targets
          .where((s) => !_projected.contains(s.id))
          .map((s) => s.id)
          .toSet();
      for (final slot in targets) {
        final controller = slot.controller;
        final share =
            _independent.contains(slot.id) && _independentMode == 'share';
        controller.setLiturgyShare(share);
        if (video != null && _source != null) {
          _sendToSlot(
            slot,
            PalcoMessage(
              type: 'video',
              fields: {
                'url': _address(controller, _source),
                'action': _playing ? 'play' : 'pause',
                'positionMs': _position.inMilliseconds,
                'connectionsMuted': _output == 'player',
              },
            ),
          );
        } else {
          final lyric = _lyrics.slides.isEmpty ? null : _lyrics.slides[_slide];
          final title = lyric != null && _slide != 0 ? '' : selected.name;
          final rich = RichNotes.sanitize(selected.notesHtml);
          final body = _captionsHidden
              ? ''
              : lyric != null
              ? RichNotes.fromPlainText(lyric.text)
              : rich.isNotEmpty
              ? rich
              : RichNotes.fromPlainText(
                  selected.subtitle.isNotEmpty
                      ? selected.subtitle
                      : selected.notes ?? '',
                );
          final titleColor = RichNotes.titleColor(selected.titleColor);
          final text = [
            if (!_captionsHidden && title.isNotEmpty)
              '<span style="color:${titleColor.isEmpty ? '#ffffff' : titleColor}">${const HtmlEscape().convert(title)}</span>',
            body,
          ].where((s) => s.isNotEmpty).join('<br>');
          final background = _preview != null
              ? controller.serveMedia(
                  'local-liturgy-${selected.id}-$_slide.png',
                  _preview!,
                )
              : _backgrounds.isNotEmpty
              ? _address(controller, _backgrounds[_slide])
              : null;
          final settings = slot.settings;
          _sendToSlot(
            slot,
            PalcoMessage.projection(
              text: lyric != null && _slide == 0
                  ? (_captionsHidden ? '' : const HtmlEscape().convert(title))
                  : text,
              background: background,
              scope: 'liturgy',
              fontSize: settings.fontSize,
              fontWeight: settings.fontWeight.value,
              textAlign: settings.textAlign,
              textVerticalAlign: settings.textVerticalAlign,
              textShadow: settings.textShadow,
              textBox: settings.textBox,
            ),
          );
        }
        _projected.add(slot.id);
        if (added.contains(slot.id) && _audio != null && _output != 'player') {
          _startAudio(slot);
        }
      }
      _projecting = targets.isNotEmpty;
    } else if (video != null && _source != null) {
      _projecting = _stage.playVideoOnStage(_source!);
    } else if (_preview != null) {
      _projecting = _stage.projectWebSnapshot(_preview!);
    } else {
      final lyric = _lyrics.slides.isEmpty ? null : _lyrics.slides[_slide];
      final rich = RichNotes.sanitize(selected.notesHtml);
      _projecting = await _stage.project(
        title: _captionsHidden
            ? ''
            : lyric == null || _slide == 0
            ? selected.name
            : '',
        body: _captionsHidden
            ? ''
            : lyric?.text ??
                  (rich.isNotEmpty
                      ? RichNotes.plainText(rich)
                      : selected.subtitle),
        richBody: _captionsHidden || rich.isEmpty ? null : rich,
        titleColor: RichNotes.titleColor(selected.titleColor),
        background: lyric?.imageUrl,
        module: 'liturgy',
      );
    }
    _emit();
  }

  void _startAudio(PalcoSlot slot) {
    _sendToSlot(
      slot,
      PalcoMessage(
        type: 'audio',
        fields: {
          'url': _address(slot.controller, _source),
          'action': _playing ? 'play' : 'pause',
          'positionMs': _position.inMilliseconds,
          'title': item?.name,
        },
      ),
    );
  }

  Future<void> _routeAudio() async {
    final volume = _output == 'connections' && _projecting
        ? 0.0
        : _volume / 100;
    await _audio?.setVolume(volume);
    await video?.setVolume(volume);
    if (_palco.anyConnected) {
      _sendLive(PalcoMessage(type: 'audioOutput', fields: {'mode': _output}));
    } else {
      _stage.audioRoute = switch (_output) {
        'connections' => PalcoAudioRoute.tv,
        'both' => PalcoAudioRoute.mirror,
        _ => PalcoAudioRoute.local,
      };
    }
  }

  Future<void> _commandTail = Future<void>.value();
  @override
  Future<void> send(RemoteCommand command) {
    final operation = _commandTail.then((_) => _executeCommand(command));
    _commandTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _executeCommand(RemoteCommand command) async {
    switch (command.action) {
      case RemoteAction.stop:
        ++_generation;
        await _release();
        break;
      case RemoteAction.play:
      case RemoteAction.pause:
      case RemoteAction.toggle:
        final play =
            command.action == RemoteAction.play ||
            (command.action == RemoteAction.toggle && !_playing);
        final wasPlaying = _playing;
        if (play) {
          await _audio?.resume();
          await video?.play();
        } else {
          await _audio?.pause();
          await video?.pause();
        }
        if (_projecting && wasPlaying != play) {
          if (_palco.anyConnected) {
            _sendLive(
              PalcoMessage(
                type: video != null ? 'video' : 'audio',
                fields: {'action': play ? 'play' : 'pause'},
              ),
            );
          } else if (video != null) {
            if (_palco.anyConnected) {
              _palco.toggleStageVideoPause();
            } else {
              _stage.toggleStageVideoPause();
            }
          } else if (play)
            _stage.resumeHymnAudio();
          else
            _stage.pauseHymnAudio();
        }
        _playing = play;
        break;
      case RemoteAction.seek:
        final position = command.position ?? Duration.zero;
        await _audio?.seek(position);
        await video?.seekTo(position);
        if (_projecting) {
          if (_palco.anyConnected) {
            _sendLive(
              PalcoMessage(
                type: video != null ? 'video' : 'audio',
                fields: {
                  'action': 'seek',
                  'positionMs': position.inMilliseconds,
                },
              ),
            );
            // O receiver retoma a mídia pausada ao receber seek.
            if (!_playing) {
              _sendLive(
                PalcoMessage(
                  type: video != null ? 'video' : 'audio',
                  fields: const {'action': 'pause'},
                ),
              );
            }
          } else if (_audio != null)
            _stage.seekHymnAudio(position);
        }
        _position = position;
        break;
      case RemoteAction.setVolume:
        _volume = (command.volume ?? _volume).clamp(0, 100);
        await _routeAudio();
        break;
      case RemoteAction.slideNext:
        await _slideTo(_slide + 1);
        break;
      case RemoteAction.slidePrevious:
        await _slideTo(_slide - 1);
        break;
      case RemoteAction.videoToggleProjection:
        if (_projecting) {
          await _stopProjection();
        } else {
          await _project();
        }
        await _routeAudio();
        break;
      case RemoteAction.videoSetAudioOutput:
        final previous = _output;
        _output = command.mode ?? 'player';
        if (previous != _output && _projecting && _audio != null) {
          for (final slot in _targets) {
            if (_output == 'player') {
              _sendToSlot(
                slot,
                const PalcoMessage(type: 'audio', fields: {'action': 'stop'}),
              );
            } else {
              _startAudio(slot);
            }
          }
        }
        await _routeAudio();
        break;
      case RemoteAction.videoToggleCaptions:
        _captionsHidden = !_captionsHidden;
        if (_projecting) await _project();
        break;
      case RemoteAction.videoSetTarget:
        if (command.targetId != null) {
          await _palco.setMuted(command.targetId!, command.enabled != true);
          if (_projecting) await _project();
        }
        break;
      case RemoteAction.videoSetIndependentMode:
        if (command.mode == 'overlay' || command.mode == 'share') {
          _independentMode = command.mode!;
          for (final id in _independent) {
            await _palco.setMuted(id, _independentMode == 'overlay');
          }
          if (_projecting) await _project();
        }
        break;
      case RemoteAction.videoSetIndependentTarget:
        final id = command.targetId;
        if (id != null && _palco.slot(id)?.isConnected == true) {
          if (command.enabled == true) {
            _previousMuted.putIfAbsent(id, () => _palco.isMuted(id));
            _independent.add(id);
            await _palco.setMuted(id, _independentMode == 'overlay');
            await _project();
            await _routeAudio();
          } else {
            final slot = _palco.slot(id)!;
            _sendToSlot(slot, const PalcoMessage(type: 'idle'));
            slot.controller.setLiturgyShare(false);
            _independent.remove(id);
            _projected.remove(id);
            await _palco.setMuted(id, _previousMuted.remove(id) ?? false);
          }
        }
        break;
      case RemoteAction.setMode:
        final selected = item;
        if (selected != null && selected.type == LiturgyItemType.music) {
          final position = _position;
          final playing = _playing;
          await _open(
            selected.copyWith(musicMode: command.mode),
            _language,
            _date,
            keepProjection: true,
          );
          await _audio?.seek(position);
          _position = position;
          if (!playing) {
            await _audio?.pause();
            _playing = false;
          }
          if (_projecting) {
            await _project();
            if (_audio != null && _output != 'player') {
              for (final slot in _targets) {
                if (_projected.contains(slot.id)) _startAudio(slot);
              }
            }
          }
        }
        break;
      default:
        break;
    }
    _emit();
  }

  Future<void> _stopProjection() async {
    if (_projected.isNotEmpty) {
      _sendLive(const PalcoMessage(type: 'video', fields: {'action': 'stop'}));
      _sendLive(const PalcoMessage(type: 'audio', fields: {'action': 'stop'}));
      _sendLive(const PalcoMessage(type: 'idle'));
      for (final id in _projected) {
        _palco.slot(id)?.controller.setLiturgyShare(false);
      }
      _projected.clear();
    } else if (_projecting) {
      if (video != null) {
        _stage.stopVideoOnStage();
      } else {
        await _stage.clearContent();
      }
      _stage.stopHymnAudio();
    }
    for (final entry in _previousMuted.entries) {
      await _palco.setMuted(entry.key, entry.value);
    }
    _previousMuted.clear();
    _independent.clear();
    _projecting = false;
  }

  Future<void> _release({
    bool stopAudio = true,
    bool keepProjection = false,
  }) async {
    if (!keepProjection) await _stopProjection();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    if (stopAudio && _audio?.currentUrl == _source) await _audio?.stop();
    _audio = null;
    final controller = video;
    video = null;
    controller?.removeListener(_videoChanged);
    await controller?.dispose();
    item = null;
    _source = null;
    _lyrics = LyricSlides.empty;
    _backgrounds = [];
    _paths = [];
    _pdf = null;
    _preview = null;
    _slide = 0;
    _count = 0;
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _emit();
  }

  @override
  Future<void> updateText(LiturgyItem changed) async {
    if (item?.id != changed.id) return;
    item = changed;
    if (_projecting) await _project();
    _emit();
  }

  @override
  Future<void> dispose() async {
    ++_generation;
    nowPlaying.removeListener(_legacyChanged);
    _stage.removeListener(_emit);
    _palco.removeListener(_emit);
    await _release();
    _disposed = true;
    await _states.close();
  }
}
