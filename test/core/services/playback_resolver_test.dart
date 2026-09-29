library;

import 'package:dio/dio.dart' show ProgressCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/offline_music_port.dart';
import 'package:louvorja_piano_mobile/core/services/playback_resolver.dart';

class _MemOffline implements OfflineMusicPort {
  final Set<int> _local = {};

  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    return _local.contains(musicId) ? '/local/$musicId.mp3' : null;
  }

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) async {
    _local.add(musicId);
    return '/local/$musicId.mp3';
  }

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) async {
    _local.remove(musicId);
  }

  void seed(int id) => _local.add(id);
}

class _UnsupportedOffline implements OfflineMusicPort {
  @override
  bool get isSupported => false;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    if (!isSupported) return null;
    throw UnimplementedError();
  }

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) =>
      throw UnimplementedError();
}

class _CrashOffline implements OfflineMusicPort {
  @override
  bool get isSupported => true;

  @override
  Future<String?> localPathFor(int musicId, {bool instrumental = false}) {
    throw Exception('disk error');
  }

  @override
  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    ProgressCallback? onReceiveProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> remove(int musicId, {bool instrumental = false}) =>
      throw UnimplementedError();
}

void main() {
  group('PlaybackResolver', () {
    test('faixa baixada: toca arquivo local (offline-first)', () async {
      final offline = _MemOffline();
      offline.seed(42);
      final r = await PlaybackResolver.resolve(
        musicId: 42,
        onlineUrl: 'https://api/x.mp3',
        offline: offline,
      );
      expect(
        r.source,
        '/local/42.mp3',
        reason: 'baixado deve tocar do disco, nao streaming',
      );
      expect(r.isLocal, isTrue);
    });

    test('nao baixada: mantem URL remota', () async {
      final offline = _MemOffline();
      final r = await PlaybackResolver.resolve(
        musicId: 43,
        onlineUrl: 'https://api/x.mp3',
        offline: offline,
      );
      expect(r.source, 'https://api/x.mp3');
      expect(r.isLocal, isFalse);
    });

    test('instrumental segue chave propria no indice offline', () async {
      final offline = _MemOffline();
      final r = await PlaybackResolver.resolve(
        musicId: 99,
        onlineUrl: 'https://api/i.mp3',
        instrumental: true,
        offline: offline,
      );
      expect(
        r.source,
        'https://api/i.mp3',
        reason: 'instrumental nao baixado cai na URL remota',
      );
    });

    test('nao suportado (web): URL remota direto', () async {
      final r = await PlaybackResolver.resolve(
        musicId: 1,
        onlineUrl: 'https://api/x.mp3',
        offline: _UnsupportedOffline(),
      );
      expect(r.source, 'https://api/x.mp3');
      expect(r.isLocal, isFalse);
    });

    test('offline nao suportado nao quebra resolve', () async {
      final r = await PlaybackResolver.resolve(
        musicId: 2,
        onlineUrl: 'https://api/x.mp3',
        offline: _CrashOffline(),
      );
      expect(r.source, 'https://api/x.mp3');
    });
  });
}
