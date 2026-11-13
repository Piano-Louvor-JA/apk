import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/hymn_audio_player.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_playback.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/data/repositories/local_liturgy_media_impl.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:mocktail/mocktail.dart';

class Audio extends Mock implements HymnAudioPlayer {}

class Video extends VideoPlayerController {
  Video() : super.networkUrl(Uri.parse('https://example.test/clip.mp4'));
  bool released = false;
  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(minutes: 2),
      isInitialized: true,
      size: Size(1920, 1080),
    );
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setVolume(double volume) async {
    value = value.copyWith(volume: volume);
  }

  // O fake não inicializa recursos nativos para liberar no super.
  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    released = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Audio audio;
  late LocalLiturgyMediaImpl media;
  late StreamController<Duration> positions;
  late String? source;
  setUp(() {
    positions = StreamController<Duration>.broadcast(sync: true);
    source = null;
    audio = Audio();
    when(() => audio.positionStream).thenAnswer((_) => positions.stream);
    when(() => audio.durationStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.playingStream).thenAnswer((_) => const Stream.empty());
    when(() => audio.currentUrl).thenAnswer((_) => source);
    when(() => audio.playUrl(any())).thenAnswer((call) async {
      source = call.positionalArguments.first as String;
    });
    when(() => audio.setVolume(any())).thenAnswer((_) async {});
    when(() => audio.seek(any())).thenAnswer((_) async {});
    when(() => audio.pause()).thenAnswer((_) async {});
    when(() => audio.resume()).thenAnswer((_) async {});
    when(() => audio.stop()).thenAnswer((_) async {
      source = null;
    });
    media = LocalLiturgyMediaImpl(
      audio: audio,
      resolveMusic: (item, language) async => LiturgyMusicPlayback(
        detail: const Hymn(
          id: 1,
          title: 'Digno',
          imageUrl: 'https://example.test/cover.jpg',
          durationMs: 60000,
          lyricRaw: [
            {'lyric': 'Santo', 'show_slide': 1, 'order': 1, 'time': '00:10'},
          ],
        ),
        source: '/download/digno.mp3',
        isLocal: true,
      ),
    );
  });
  tearDown(() async {
    await media.dispose();
    await positions.close();
  });
  setUpAll(() => registerFallbackValue(Duration.zero));
  const song = LiturgyItem(
    id: 'music',
    name: 'Digno',
    type: LiturgyItemType.music,
    musicId: 1,
  );
  test(
    'música local preserva fundo, duração, letra e troca sincronizada',
    () async {
      await media.open(song, 'pt', DateTime(2026));
      expect(media.snapshot.playing, true);
      expect(media.snapshot.slideCount, 2);
      expect(media.snapshot.slideBackgroundSources, [
        'https://example.test/cover.jpg',
        'https://example.test/cover.jpg',
      ]);
      expect(media.snapshot.videoControls!.projecting, false);
      positions.add(const Duration(seconds: 12));
      expect(media.snapshot.slideIndex, 1);
      expect(media.snapshot.duration, const Duration(minutes: 1));
      await media.send(
        RemoteCommand(id: 's', action: RemoteAction.slidePrevious),
      );
      verify(() => audio.seek(Duration.zero)).called(1);
      await media.send(
        RemoteCommand(id: 'v', action: RemoteAction.setVolume, volume: 35),
      );
      verify(() => audio.setVolume(.35)).called(1);
      await media.send(RemoteCommand(id: 'p', action: RemoteAction.pause));
      expect(media.snapshot.playing, false);
      await media.send(RemoteCommand(id: 'r', action: RemoteAction.play));
      expect(media.snapshot.playing, true);
      await media.send(RemoteCommand(id: 'x', action: RemoteAction.stop));
      expect(media.snapshot.hasOpenMedia, false);
      verify(() => audio.stop()).called(1);
    },
  );
  test(
    'imagens e PDF navegam localmente e fecham sem projeção automática',
    () async {
      final dir = await Directory.systemTemp.createTemp('local-liturgy-test');
      addTearDown(() => dir.delete(recursive: true));
      final a = await File('${dir.path}/a.png').writeAsBytes([1, 2]);
      final b = await File('${dir.path}/b.png').writeAsBytes([3, 4]);
      await media.open(
        LiturgyItem(
          id: 'images',
          name: 'Fotos',
          type: LiturgyItemType.images,
          filePaths: [a.path, b.path],
        ),
        'pt',
        DateTime(2026),
      );
      expect(base64Decode(media.snapshot.slidePreview!), [1, 2]);
      await media.send(RemoteCommand(id: 'n', action: RemoteAction.slideNext));
      expect(media.snapshot.slideIndex, 1);
      expect(base64Decode(media.snapshot.slidePreview!), [3, 4]);
      await media.send(RemoteCommand(id: 'n', action: RemoteAction.slideNext));
      expect(media.snapshot.slideIndex, 1);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('app.louvorja/liturgy-documents');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'pdfInfo'
            ? 2
            : Uint8List.fromList([call.arguments['page'] as int]),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await media.open(
        const LiturgyItem(
          id: 'pdf',
          name: 'PDF',
          type: LiturgyItemType.pdf,
          filePath: '/doc.pdf',
        ),
        'pt',
        DateTime(2026),
      );
      expect(media.snapshot.slideCount, 2);
      await media.send(RemoteCommand(id: 'n', action: RemoteAction.slideNext));
      expect(base64Decode(media.snapshot.slidePreview!), [1]);
      expect(media.snapshot.videoControls!.projecting, false);
    },
  );
  test(
    'anotações e anúncios usam o mesmo contrato e só projetam por comando',
    () async {
      for (final type in [LiturgyItemType.annotation, LiturgyItemType.notice]) {
        await media.open(
          LiturgyItem(
            id: type.name,
            name: 'Aviso',
            type: type,
            notesHtml: '<b>Olá</b>',
          ),
          'pt',
          DateTime(2026),
        );
        expect(media.snapshot.title, 'Aviso');
        expect(media.snapshot.duration, Duration.zero);
        expect(media.snapshot.videoControls!.projecting, false);
        await media.send(RemoteCommand(id: 'x', action: RemoteAction.stop));
        expect(media.snapshot.hasOpenMedia, false);
      }
    },
  );
  test(
    'vídeo nativo preserva posição, pausa, volume e libera controller ao fechar',
    () async {
      final video = Video();
      final local = LocalLiturgyMediaImpl(createVideo: (_) => video);
      await local.open(
        const LiturgyItem(
          id: 'v',
          type: LiturgyItemType.video,
          name: 'Vídeo',
          filePath: '/clip.mp4',
        ),
        'pt',
        DateTime(2026),
      );
      expect(local.snapshot.playing, true);
      expect(local.snapshot.duration, const Duration(minutes: 2));
      expect(local.snapshot.videoControls!.projecting, false);
      await local.send(
        RemoteCommand(
          id: 's',
          action: RemoteAction.seek,
          position: const Duration(seconds: 25),
        ),
      );
      expect(local.snapshot.position, const Duration(seconds: 25));
      await local.send(RemoteCommand(id: 'p', action: RemoteAction.pause));
      expect(local.snapshot.playing, false);
      expect(video.released, false);
      await local.send(
        RemoteCommand(id: 'v', action: RemoteAction.setVolume, volume: 42),
      );
      expect(video.value.volume, .42);
      await local.send(RemoteCommand(id: 'x', action: RemoteAction.stop));
      expect(local.snapshot.hasOpenMedia, false);
      expect(video.released, true);
      await local.dispose();
    },
  );
  test(
    'toques rápidos nos slides mantêm a ordem de leitura dos arquivos',
    () async {
      final dir = await Directory.systemTemp.createTemp('local-slide-queue');
      addTearDown(() => dir.delete(recursive: true));
      final files = <String>[];
      for (var i = 0; i < 3; i++) {
        files.add((await File('${dir.path}/$i.png').writeAsBytes([i])).path);
      }
      await media.open(
        LiturgyItem(
          id: 'queue',
          type: LiturgyItemType.images,
          name: 'Slides',
          filePaths: files,
        ),
        'pt',
        DateTime(2026),
      );
      await Future.wait([
        media.send(RemoteCommand(id: 'one', action: RemoteAction.slideNext)),
        media.send(RemoteCommand(id: 'two', action: RemoteAction.slideNext)),
      ]);
      expect(media.snapshot.slideIndex, 2);
      expect(base64Decode(media.snapshot.slidePreview!), [2]);
    },
  );
  test(
    'PDF fechado durante carregamento não substitui o próximo conteúdo',
    () async {
      final count = Completer<int>();
      final requested = Completer<void>();
      const channel = MethodChannel('app.louvorja/liturgy-documents');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pdfInfo') {
          requested.complete();
          return count.future;
        }
        return Uint8List.fromList([1]);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final opening = media.open(
        const LiturgyItem(
          id: 'old',
          name: 'PDF',
          type: LiturgyItemType.pdf,
          filePath: '/old.pdf',
        ),
        'pt',
        DateTime(2026),
      );
      await requested.future;
      await media.send(RemoteCommand(id: 'stop', action: RemoteAction.stop));
      await media.open(
        const LiturgyItem(
          id: 'new',
          name: 'Anotação',
          type: LiturgyItemType.annotation,
        ),
        'pt',
        DateTime(2026),
      );
      count.complete(2);
      await opening;
      expect(media.snapshot.title, 'Anotação');
      expect(media.snapshot.slideCount, 0);
      expect(media.snapshot.slidePreview, isNull);
    },
  );
  test(
    'vídeo parado no fim recomeça do início ao tocar, como no desktop',
    () async {
      final video = Video();
      final local = LocalLiturgyMediaImpl(createVideo: (_) => video);
      addTearDown(local.dispose);
      await local.open(
        const LiturgyItem(
          id: 'v',
          type: LiturgyItemType.video,
          name: 'Vídeo',
          filePath: '/clip.mp4',
        ),
        'pt',
        DateTime(2026),
      );
      // Terminou: o plugin para na última posição, sem voltar ao início.
      await video.pause();
      await video.seekTo(const Duration(minutes: 2));
      await local.send(RemoteCommand(id: 'p', action: RemoteAction.play));

      expect(video.value.position, Duration.zero);
      expect(video.value.isPlaying, true);
      expect(local.snapshot.playing, true);

      // No meio do vídeo, tocar continua de onde parou.
      await video.pause();
      await video.seekTo(const Duration(seconds: 30));
      await local.send(RemoteCommand(id: 'p2', action: RemoteAction.play));
      expect(video.value.position, const Duration(seconds: 30));
    },
  );
}
