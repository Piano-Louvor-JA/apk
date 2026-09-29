library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/web_link_server.dart';

void main() {
  late WebLinkServer server;

  setUp(() {
    server = WebLinkServer();
  });

  tearDown(() async {
    await server.stop();
  });

  RemotePlayerState sampleState() => const RemotePlayerState(
    hymnId: 15,
    title: 'Rocha Eterna',
    mode: 'audio',
    playing: true,
    position: Duration(seconds: 34),
    duration: Duration(minutes: 3),
    slideIndex: 2,
    slideCount: 5,
    volume: 80,
    canPrevious: true,
    canNext: false,
  );

  test('start expõe porta e URL ws com token na query', () async {
    final url = await server.start(token: 'ABC123');
    expect(url, isNotNull);
    expect(url!.startsWith('ws://'), isTrue);
    expect(url.contains('?t=ABC123'), isTrue);
    expect(server.isRunning, isTrue);
  });

  test('web conecta com token certo → clientEvents true', () async {
    final url = await server.start(token: 'CERTO');
    expect(url, isNotNull);

    final events = <bool>[];
    final connected = Completer<void>();
    server.clientEvents.listen((b) {
      events.add(b);
      if (b && !connected.isCompleted) connected.complete();
    });

    final client = await WebSocket.connect(url!);
    await connected.future.timeout(const Duration(seconds: 5));
    expect(events, [true]);
    expect(server.hasClient, isTrue);
    await client.close();
  });

  test('token errado na URL → handshake recusado (401), sem socket', () async {
    final url = await server.start(token: 'CERTO');
    expect(url, isNotNull);
    final badUrl = url!.replaceFirst('t=CERTO', 't=ERRADO');

    await expectLater(WebSocket.connect(badUrl), throwsA(anything));
    expect(server.hasClient, isFalse);
  });

  test('segundo cliente enquanto um está conectado → recusado (409)', () async {
    final url = await server.start(token: 'T');
    final connected = Completer<void>();
    server.clientEvents.listen((b) {
      if (b && !connected.isCompleted) connected.complete();
    });
    final first = await WebSocket.connect(url!);
    await connected.future.timeout(const Duration(seconds: 5));

    await expectLater(WebSocket.connect(url), throwsA(anything));
    await first.close();
  });

  test('web envia state → APK recebe no stream states', () async {
    final url = await server.start(token: 'T');
    final connected = Completer<void>();
    server.clientEvents.listen((b) {
      if (b && !connected.isCompleted) connected.complete();
    });
    final client = await WebSocket.connect(url!);
    await connected.future.timeout(const Duration(seconds: 5));

    final states = <RemotePlayerState>[];
    final got = Completer<void>();
    server.states.listen((s) {
      states.add(s);
      if (!got.isCompleted) got.complete();
    });

    client.add(sampleState().encode());
    await got.future.timeout(const Duration(seconds: 5));
    expect(states.single.title, 'Rocha Eterna');
    expect(states.single.playing, isTrue);
    await client.close();
  });

  test('APK sendCommand → web recebe o comando', () async {
    final url = await server.start(token: 'T');
    final connected = Completer<void>();
    server.clientEvents.listen((b) {
      if (b && !connected.isCompleted) connected.complete();
    });
    final client = await WebSocket.connect(url!);
    await connected.future.timeout(const Duration(seconds: 5));

    final frames = <String>[];
    final got = Completer<void>();
    client.listen((d) {
      frames.add(d as String);
      if (!got.isCompleted) got.complete();
    });

    final ok = server.sendCommand(
      RemoteCommand(id: 'c1', action: RemoteAction.next),
    );
    expect(ok, isTrue);
    await got.future.timeout(const Duration(seconds: 5));
    expect(frames.single, contains('"player.next"'));
    await client.close();
  });

  test('sendCommand sem cliente → false (não lança)', () async {
    await server.start(token: 'T');
    expect(
      server.sendCommand(RemoteCommand(id: 'x', action: RemoteAction.play)),
      isFalse,
    );
  });

  test('estado enviado pelo web preserva itens da liturgia no JSON', () {
    const state = RemotePlayerState(
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      slideIndex: 0,
      slideCount: 0,
      volume: 80,
      canPrevious: false,
      canNext: true,
      liturgyItems: [
        RemoteLiturgyItem(
          index: 0,
          type: 'hymn',
          title: 'Santo, Santo, Santo',
          done: false,
        ),
      ],
      liturgySelectedIndex: 0,
    );

    final json = state.encode();
    expect(json, contains('"liturgy"'));
    expect(json, contains('Santo, Santo, Santo'));
    expect(json, contains('"selectedIndex":0'));
  });

  test('web responde ack → APK recebe', () async {
    final url = await server.start(token: 'T');
    final connected = Completer<void>();
    server.clientEvents.listen((b) {
      if (b && !connected.isCompleted) connected.complete();
    });
    final client = await WebSocket.connect(url!);
    await connected.future.timeout(const Duration(seconds: 5));

    final acks = <RemoteAck>[];
    final got = Completer<void>();
    server.acks.listen((a) {
      acks.add(a);
      if (!got.isCompleted) got.complete();
    });

    client.add(RemoteAck(id: 'c1', ok: true).encode());
    await got.future.timeout(const Duration(seconds: 5));
    expect(acks.single.ok, isTrue);
    await client.close();
  });

  test('web manda ping → APK responde pong', () async {
    final url = await server.start(token: 'T');
    final connected = Completer<void>();
    server.clientEvents.listen((b) {
      if (b && !connected.isCompleted) connected.complete();
    });
    final client = await WebSocket.connect(url!);
    await connected.future.timeout(const Duration(seconds: 5));

    final frames = <String>[];
    final got = Completer<void>();
    client.listen((d) {
      frames.add(d as String);
      if (d.contains('pong') && !got.isCompleted) got.complete();
    });

    client.add(const RemotePing().encode());
    await got.future.timeout(const Duration(seconds: 5));
    expect(frames, isNotEmpty);
    await client.close();
  });

  test(
    'web desconecta → clientEvents false; novo cliente pode conectar',
    () async {
      final url = await server.start(token: 'T');
      final first = await WebSocket.connect(url!);
      final events = <bool>[];
      final down = Completer<void>();
      server.clientEvents.listen((b) {
        events.add(b);
        if (!b && !down.isCompleted) down.complete();
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await first.close();
      await down.future.timeout(const Duration(seconds: 5));

      final second = await WebSocket.connect(url);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(server.hasClient, isTrue);
      await second.close();
    },
  );

  test('stop fecha servidor e derruba cliente', () async {
    final url = await server.start(token: 'T');
    final client = await WebSocket.connect(url!);
    final closed = Completer<void>();
    client.listen(
      (_) {},
      onDone: () {
        if (!closed.isCompleted) closed.complete();
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await server.stop();
    await closed.future.timeout(const Duration(seconds: 5));
    expect(server.isRunning, isFalse);
  });
}
