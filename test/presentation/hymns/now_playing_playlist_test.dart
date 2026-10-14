import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/now_playing.dart';
import 'package:louvorja_piano_mobile/domain/entities/hymn.dart';
import 'package:louvorja_piano_mobile/presentation/hymns/now_playing_page.dart';
import 'package:louvorja_piano_mobile/data/datasources/local/playlist_storage.dart';

class _FakePlayer extends HymnPlayerLike {
  final _playing = ValueNotifier<bool>(true);
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  Duration? sought;
  int pauses = 0;
  int stops = 0;

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
  Future<void> pause() async {
    pauses++;
    _playing.value = false;
  }

  @override
  Future<void> resume() async => _playing.value = true;

  @override
  Future<void> stop() async {
    stops++;
    _playing.value = false;
  }
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

Future<void> _pump(WidgetTester tester, HymnPlayerLike player) async {
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
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adicionar a playlist existente mostra snackbar de sucesso', (
    tester,
  ) async {
    final storage = PlaylistStorage();
    await storage.create('Culto');
    final player = _FakePlayer();
    await _pump(tester, player);

    await tester.tap(find.byIcon(TablerIcons.playlist));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar à playlist'), findsOneWidget);
    expect(find.text('Culto'), findsOneWidget);
    expect(find.text('0 hinos'), findsOneWidget);

    await tester.tap(find.text('Culto'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Nosso Sol é Jesus" adicionada à playlist.'),
      findsOneWidget,
    );
    final playlists = await storage.list();
    expect(playlists.single.items.single.musicId, 1);
    expect(playlists.single.items.single.title, 'Nosso Sol é Jesus');
  });

  testWidgets('sem playlists oferece criar nova pelo fluxo do diálogo', (
    tester,
  ) async {
    final player = _FakePlayer();
    await _pump(tester, player);

    await tester.tap(find.byIcon(TablerIcons.playlist));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhuma playlist ainda — crie a primeira.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Criar nova playlist'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Louvores novas');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Nosso Sol é Jesus" adicionada à playlist.'),
      findsOneWidget,
    );
    final playlists = await PlaylistStorage().list();
    expect(playlists.single.name, 'Louvores novas');
    expect(playlists.single.items.single.musicId, 1);
  });

  testWidgets('criar playlist com nome vazio não cria nada', (tester) async {
    final player = _FakePlayer();
    await _pump(tester, player);

    await tester.tap(find.byIcon(TablerIcons.playlist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar nova playlist'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final playlists = await PlaylistStorage().list();
    expect(playlists, isEmpty);
  });

  testWidgets('item duplicado na playlist mostra snackbar de posição', (
    tester,
  ) async {
    final storage = PlaylistStorage();
    final playlist = await storage.create('Duplicado');
    await storage.addItem(
      playlist.id,
      const PlaylistItem(musicId: 1, title: 'Nosso Sol é Jesus'),
    );
    final player = _FakePlayer();
    await _pump(tester, player);

    await tester.tap(find.byIcon(TablerIcons.playlist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicado'));
    await tester.pumpAndSettle();

    expect(find.text('Já é a última faixa da playlist.'), findsOneWidget);
  });

  testWidgets('fechar o sheet sem escolher não altera playlists', (
    tester,
  ) async {
    final storage = PlaylistStorage();
    await storage.create('Culto');
    final player = _FakePlayer();
    await _pump(tester, player);

    await tester.tap(find.byIcon(TablerIcons.playlist));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 300));
    await tester.pumpAndSettle();

    final playlists = await storage.list();
    expect(playlists.single.items, isEmpty);
  });
}
