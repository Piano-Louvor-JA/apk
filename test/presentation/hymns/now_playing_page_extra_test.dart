import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';

class _FakePlayer extends HymnPlayerLike {
  final _playing = ValueNotifier<bool>(true);
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  Duration? sought;
  var stopped = false;

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
  Future<void> stop() async {
    stopped = true;
    _playing.value = false;
  }
}

Hymn _detail({bool hasInstrumental = false}) => Hymn(
      id: 1,
      title: 'Nosso Sol é Jesus',
      imageUrl: '/images/capa.jpg',
      hasInstrumental: hasInstrumental,
      lyricRaw: const [
        {
          'lyric': 'O nosso sol',
          'time': '00:00:08',
          'show_slide': '1',
          'order': '1',
        },
        {
          'lyric': 'Veio iluminar',
          'time': '00:00:17',
          'show_slide': '1',
          'order': '2',
        },
      ],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('botão X para o áudio local e fecha a página', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Minimizar (música continua)'));
    await tester.pump();
    expect(player.stopped, isFalse); // minimizar NÃO para

    // Reabre pra testar o X (página foi popada).
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.x).first, warnIfMissed: false);
    await tester.pump();
    expect(player.stopped, isTrue);
  });

  testWidgets('modo instrumental: botão de alternância aparece', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(hasInstrumental: true),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Instrumental'), findsOneWidget);
    await tester.tap(find.byTooltip('Instrumental'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem hasInstrumental: botão de modo não aparece', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Instrumental'), findsNothing);
  });

  testWidgets('prev slide no índice 0 não faz seek negativo', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    final prev = find.byIcon(TablerIcons.chevronLeft);
    expect(prev, findsOneWidget);
    await tester.tap(prev);
    await tester.pump();
    expect(player.sought, isNull); // já está no primeiro slide
    expect(tester.takeException(), isNull);
  });

  testWidgets('avançar slide procura o timestamp da próxima letra', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(TablerIcons.chevronRight));
    await tester.pump();
    expect(player.sought, const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('salvar em coletânea abre sheet sem crash', (tester) async {
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Salvar em coletânea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adicionar à playlist: sheet lista playlists salvas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'louvorja.playlists': '''
[{"id":"p1","name":"Culto","items":[]}]
''',
    });
    final player = _FakePlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingPage(
          detail: _detail(),
          instrumental: false,
          player: player,
          filesUrl: 'https://api.test/file',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Adicionar à playlist'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar à playlist'), findsOneWidget);
    expect(find.text('Culto'), findsOneWidget);
    expect(find.text('Criar nova playlist'), findsOneWidget);
  });
}
