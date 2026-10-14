library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/core/services/dlna/stage_session.dart';
import 'package:louvorja_piano_mobile/core/services/palco/palco_controller.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';

class _FakeOffline extends Fake implements OfflineMusicPort {
  String? local;
  @override
  bool get isSupported => true;
  @override
  Future<String?> localPathFor(
    int musicId, {
    bool instrumental = false,
  }) async => local;
}

class _FakePlayer extends HymnPlayerLike {
  final _playing = ValueNotifier<bool>(true);
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  Duration? sought;
  final playedUrls = <String>[];
  Completer<void>? pendingPlay;
  bool failPlay = false;
  bool failResume = false;
  double? lastVolumeValue;

  @override
  Future<void> playSource(String url) async {
    playedUrls.add(url);
    if (pendingPlay != null) await pendingPlay!.future;
    if (failPlay) throw StateError("falha de transporte");
    _playing.value = true;
  }

  @override
  Future<void> setVolume(double v) async => lastVolumeValue = v;

  @override
  bool get isPlaying => _playing.value;

  @override
  ValueListenable<bool> get playingListenable => _playing;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration> get durationStream => durations.stream;

  @override
  Future<void> seek(Duration position) async => sought = position;

  @override
  Future<void> pause() async => _playing.value = false;

  @override
  Future<void> resume() async {
    if (failResume) {
      throw StateError('falha ao retomar');
    }
    _playing.value = true;
  }

  @override
  Future<void> stop() async => _playing.value = false;
}

Hymn _detail() => Hymn(
  id: 1,
  title: 'Nosso Sol é Jesus',
  imageUrl: '/images/capa.jpg',
  lyricRaw: const [
    {
      'lyric': 'O nosso sol',
      'time': '00:00:08',
      'instrumental_time': '00:00:08',
      'url_image': '/images/hasd.jpg',
      'show_slide': '1',
      'order': '1',
    },
    {
      'lyric': 'Veio iluminar',
      'time': '00:00:17',
      'instrumental_time': '00:00:17',
      'show_slide': '1',
      'order': '2',
    },
  ],
);

class _Receiver {
  WebSocket? socket;
  StreamSubscription<dynamic>? subscription;
  final received = <Map<String, dynamic>>[];
  Future<void> connect(String host, int port) async {
    socket = await WebSocket.connect('ws://$host:$port/palco');
    subscription = socket!.listen(
      (data) =>
          received.add(jsonDecode(data as String) as Map<String, dynamic>),
    );
  }

  Future<void> close() async {
    await subscription?.cancel();
    await socket?.close();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const wakeChannel =
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  setUp(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      wakeChannel,
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(wakeChannel, null);
  });

  testWidgets('troca de slide automática pelo tempo do áudio', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          offlineService: _FakeOffline(),
          filesUrl: 'https://api.louvorja.com.br/file',
        ),
      ),
    );
    await tester.pump();

    // Capa (índice 0): mostra título
    expect(find.text('Nosso Sol é Jesus'), findsWidgets);

    // Áudio avança para 9s: slide 1 ("O nosso sol")
    player.positions.add(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('O nosso sol'), findsOneWidget);

    // 18s: slide 2
    player.positions.add(const Duration(seconds: 18));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Veio iluminar'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('toque em next slide faz seek do áudio pro time do slide', (
    tester,
  ) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          offlineService: _FakeOffline(),
          filesUrl: 'https://api.louvorja.com.br/file',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(TablerIcons.chevronRight).first);
    await tester.pump();

    expect(player.sought, const Duration(seconds: 8));
    expect(find.text('O nosso sol'), findsOneWidget);
  });

  testWidgets('botão instrumental troca a FONTE do áudio e o ícone', (
    tester,
  ) async {
    final player = _FakePlayer();
    final detail = Hymn(
      id: 1,
      title: 'Nosso Sol é Jesus',
      hasInstrumental: true,
      urlMusic: '/musics/pt/hino.mp3',
      urlInstrumental: '/musics/pt/hino_instr.mp3',
      lyricRaw: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: detail,
          instrumental: false,
          player: player,
          offlineService: _FakeOffline(),
          filesUrl: 'https://api.louvorja.com.br/file',
        ),
      ),
    );
    await tester.pump();

    // Modo cantado: ícone piano (convite pra ir pro instrumental).
    expect(find.byIcon(TablerIcons.piano), findsOneWidget);
    expect(player.playedUrls, isEmpty);

    await tester.tap(find.byIcon(TablerIcons.piano));
    await tester.pump();

    // FONTE trocou pra URL instrumental (mesmo builder do app).
    expect(
      player.playedUrls,
      contains(DownloadUrlBuilder.build('/musics/pt/hino_instr.mp3')),
    );
    // Ícone agora reflete modo instrumental (microfone = voltar pro cantado).
    expect(find.byIcon(TablerIcons.microphone), findsOneWidget);
    // Posição reinicia: slides seguem o tempo instrumental.
    expect(find.byIcon(TablerIcons.piano), findsNothing);

    // Volta pro cantado: toca a URL cantada de novo.
    await tester.tap(find.byIcon(TablerIcons.microphone));
    await tester.pump();
    expect(
      player.playedUrls,
      contains(DownloadUrlBuilder.build('/musics/pt/hino.mp3')),
    );
    expect(find.byIcon(TablerIcons.piano), findsOneWidget);
  });

  testWidgets('sem áudio pausa o player de verdade e retoma ao desligar', (
    tester,
  ) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          offlineService: _FakeOffline(),
          filesUrl: 'https://api.louvorja.com.br/file',
        ),
      ),
    );
    await tester.pump();

    expect(player.isPlaying, isTrue);

    // Liga "sem áudio": player PAUSA (não só esconde a timeline).
    await tester.tap(find.byIcon(TablerIcons.volumeOff));
    await tester.pump();
    expect(player.isPlaying, isFalse);

    // Desliga: player retoma.
    await tester.tap(find.byIcon(TablerIcons.volume));
    await tester.pump();
    expect(player.isPlaying, isTrue);
  });
  Hymn modes() => Hymn(
    id: 1,
    title: 'Hino',
    hasInstrumental: true,
    urlMusic: 'https://example.com/cantado.mp3',
    urlInstrumental: 'https://example.com/instrumental.mp3',
    lyricRaw: const [],
  );

  Future<void> showModes(WidgetTester tester, _FakePlayer player) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: modes(),
          instrumental: false,
          player: player,
          offlineService: _FakeOffline(),
          filesUrl: 'https://api.louvorja.com.br/file',
          audioSource: 'https://example.com/cantado.mp3',
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('trocar modo sem áudio mantém o player pausado', (tester) async {
    final player = _FakePlayer();
    await showModes(tester, player);
    await tester.tap(find.byIcon(TablerIcons.volumeOff));
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.piano));
    await tester.pump();
    expect(player.isPlaying, isFalse);
    expect(nowPlaying.track?.instrumental, isTrue);
  });

  testWidgets('falha ao trocar fonte mantém modo anterior sem exceção solta', (
    tester,
  ) async {
    final player = _FakePlayer()..failPlay = true;
    await showModes(tester, player);
    await tester.tap(find.byIcon(TablerIcons.piano));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(TablerIcons.piano), findsOneWidget);
  });

  testWidgets('trocas simultâneas não iniciam duas fontes', (tester) async {
    final player = _FakePlayer()..pendingPlay = Completer<void>();
    await showModes(tester, player);
    await tester.tap(find.byIcon(TablerIcons.piano));
    await tester.pump();
    final button = find.byIcon(TablerIcons.microphone);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button);
    } else {
      await tester.tap(find.byIcon(TablerIcons.piano));
    }
    await tester.pump();
    expect(player.playedUrls, hasLength(1));
    player.pendingPlay!.complete();
    await tester.pump();
  });

  testWidgets('troca usa download mesmo sem URL remota do modo', (
    tester,
  ) async {
    final player = _FakePlayer();
    final offline = _FakeOffline()..local = '/downloads/instrumental.mp3';
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: Hymn(
            id: 1,
            title: 'Hino',
            hasInstrumental: true,
            lyricRaw: const [],
          ),
          instrumental: false,
          player: player,
          offlineService: offline,
          filesUrl: 'https://example.com/file',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.piano));
    await tester.pump();
    expect(player.playedUrls.single, offline.local);
    expect(nowPlaying.track?.audioIsLocal, isTrue);
    expect(nowPlaying.track?.audioSource, offline.local);
  });

  testWidgets('minimizar durante troca não lança setState após dispose', (
    tester,
  ) async {
    final player = _FakePlayer()..pendingPlay = Completer<void>();
    await showModes(tester, player);
    await tester.tap(find.byIcon(TablerIcons.piano));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    player.pendingPlay!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(nowPlaying.track?.instrumental, isTrue);
  });

  testWidgets('Palco recebe a fonte nova e não retoma no modo sem áudio', (
    tester,
  ) async {
    final stage = StageSession.instance;
    final rx = _Receiver();
    await tester.runAsync(() async {
      expect(
        await stage.turnOnPalco(
          PalcoTarget(name: 'TV teste', ip: '127.0.0.1', wsPort: 0),
        ),
        isTrue,
      );
      await rx.connect('127.0.0.1', stage.palco!.wsPort);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    stage.audioRoute = PalcoAudioRoute.tv;
    final player = _FakePlayer();
    try {
      await showModes(tester, player);
      await tester.tap(find.byIcon(TablerIcons.piano));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      final audio = rx.received
          .where((m) => m['type'] == 'audio' && m['action'] == 'play')
          .last;
      expect(audio.toString(), contains('instrumental.mp3'));
      expect(audio['positionMs'], 0);
      expect(player.lastVolumeValue, 0);
      await tester.tap(find.byIcon(TablerIcons.volumeOff));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      final count = rx.received
          .where((m) => m['type'] == 'audio' && m['action'] == 'play')
          .length;
      await tester.tap(find.byIcon(TablerIcons.microphone));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      expect(
        rx.received.where((m) => m['type'] == 'audio' && m['action'] == 'play'),
        hasLength(count),
      );
      expect(player.isPlaying, isFalse);
      await tester.tap(find.byIcon(TablerIcons.volume));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      expect(player.isPlaying, isTrue);
      expect(
        rx.received
            .where((m) => m['type'] == 'audio' && m['action'] == 'play')
            .last
            .toString(),
        contains('cantado.mp3'),
      );
      expect(player.lastVolumeValue, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await rx.close();
        await stage.turnOff();
      });
      stage.audioRoute = PalcoAudioRoute.local;
    }
  });
  testWidgets('retomar áudio preserva posição do hino pausado', (tester) async {
    final player = _FakePlayer();
    await showModes(tester, player);
    player.positions.add(const Duration(seconds: 18));
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.volumeOff));
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.volume));
    await tester.pump();
    expect(player.sought, const Duration(seconds: 18));
    expect(player.lastVolumeValue, 1);
  });

  testWidgets('ícone grande alterna play/pause quando o player emite estado', (
    tester,
  ) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.louvorja.com.br/file',
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(TablerIcons.playerPause), findsOneWidget);
    expect(find.byIcon(TablerIcons.playerPlay), findsNothing);

    player._playing.value = false;
    await tester.pump();

    expect(find.byIcon(TablerIcons.playerPlay), findsOneWidget);
    expect(find.byIcon(TablerIcons.playerPause), findsNothing);

    player._playing.value = true;
    await tester.pump();

    expect(find.byIcon(TablerIcons.playerPause), findsOneWidget);
  });

  testWidgets('retomar com Palco desligado usa o player local', (tester) async {
    final stage = StageSession.instance;
    expect(stage.isOn, isFalse);
    stage.audioRoute = PalcoAudioRoute.tv;
    addTearDown(() => stage.audioRoute = PalcoAudioRoute.local);
    final player = _FakePlayer();
    await player.pause();
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://example.com/file',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.playerPlay));
    await tester.pump();
    expect(player.isPlaying, isTrue);
    expect(player.lastVolumeValue, 1);
  });

  testWidgets('falha de resume permanece pausado e mostra erro', (
    tester,
  ) async {
    final player = _FakePlayer()..failResume = true;
    await player.pause();
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://example.com/file',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.playerPlay));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(player.isPlaying, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
