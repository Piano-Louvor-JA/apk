library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/download_url_builder.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';

class _FakePlayer extends HymnPlayerLike {
  final _playing = ValueNotifier<bool>(true);
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  Duration? sought;
  final playedUrls = <String>[];
  bool? lastVolume;
  double? lastVolumeValue;

  @override
  Future<void> playSource(String url) async {
    playedUrls.add(url);
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
  Future<void> resume() async => _playing.value = true;

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

void main() {
  testWidgets('troca de slide automática pelo tempo do áudio', (tester) async {
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
}
