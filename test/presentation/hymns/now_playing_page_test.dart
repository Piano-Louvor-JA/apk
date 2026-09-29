library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';

class _FakePlayer extends HymnPlayerLike {
  final _playing = ValueNotifier<bool>(true);
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  Duration? sought;

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
}
