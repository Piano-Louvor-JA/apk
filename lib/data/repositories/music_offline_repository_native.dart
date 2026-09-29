// coverage:ignore-file Necessita filesystem nativo (path_provider/dio).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// Biblioteca local de faixas MP3.
///
/// Usa diretório privado do app: não exige permissão de arquivos no Android.
MusicOfflineRepository createMusicOfflineRepositoryImpl() =>
    throw UnsupportedError(
      'MusicOfflineRepository requer diretório privado explícito',
    );

/// Metadados de uma faixa baixada (índice v2).
///
/// Necessário para listar a biblioteca offline SEM internet: o índice v1
/// guardava só o caminho, impossibilitando montar a lista de hinos quando
/// a API está inacessível (regressão reportada 2026-08-16).
class OfflineTrackMeta {
  final int musicId;
  final String title;
  final String? number;
  final int? albumId;
  final String? albumName;
  final bool instrumental;

  const OfflineTrackMeta({
    required this.musicId,
    required this.title,
    this.number,
    this.albumId,
    this.albumName,
    this.instrumental = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    if (number != null) 'number': number,
    if (albumId != null) 'albumId': albumId,
    if (albumName != null) 'albumName': albumName,
    'instrumental': instrumental,
  };

  factory OfflineTrackMeta.fromJson(int musicId, Map<String, dynamic> json) =>
      OfflineTrackMeta(
        musicId: musicId,
        title: (json['title'] ?? '').toString(),
        number: json['number']?.toString(),
        albumId: json['albumId'] as int?,
        albumName: json['albumName']?.toString(),
        instrumental: json['instrumental'] == true,
      );
}

/// Entrada legível da biblioteca offline (índice v1 ou v2).
class OfflineTrack {
  final int musicId;
  final String path;
  final OfflineTrackMeta? meta;

  const OfflineTrack({required this.musicId, required this.path, this.meta});

  String get title => meta?.title ?? 'Hino #$musicId';
  String? get number => meta?.number;
  int? get albumId => meta?.albumId;
  String? get albumName => meta?.albumName;
}

class MusicOfflineRepository {
  static const _indexName = 'music_offline_index.json';

  final Dio _dio;
  final Directory _root;

  /// Índice v2: chave -> {path, ...meta} OU string path (v1, legado).
  Map<String, dynamic>? _index;

  MusicOfflineRepository(this._dio, String rootPath)
    : _root = Directory(rootPath);

  File get _indexFile => File('${_root.path}/$_indexName');

  Future<Map<String, dynamic>> _loadIndex() async {
    if (_index != null) return _index!;
    try {
      if (!await _indexFile.exists()) return _index = {};
      final decoded =
          jsonDecode(await _indexFile.readAsString()) as Map<String, dynamic>;
      return _index = decoded;
    } catch (_) {
      return _index = {};
    }
  }

  Future<void> _persistIndex() async {
    await _root.create(recursive: true);
    await _indexFile.writeAsString(jsonEncode(_index));
  }

  String? _pathOf(String key, dynamic entry) {
    if (entry == null) return null;
    if (entry is String) return entry;
    if (entry is Map) return entry['path']?.toString();
    return null;
  }

  Future<String?> localPathFor(int musicId, {bool instrumental = false}) async {
    final index = await _loadIndex();
    final key = _key(musicId, instrumental);
    final path = _pathOf(key, index[key]);
    if (path == null || !await File(path).exists()) {
      if (path != null) {
        index.remove(key);
        await _persistIndex();
      }
      return null;
    }
    return path;
  }

  Future<String> download({
    required int musicId,
    required String url,
    bool instrumental = false,
    OfflineTrackMeta? metadata,
    ProgressCallback? onReceiveProgress,
  }) async {
    final existing = await localPathFor(musicId, instrumental: instrumental);
    if (existing != null) return existing;

    await _root.create(recursive: true);
    final target = File('${_root.path}/${_key(musicId, instrumental)}.mp3');
    final partial = File('${target.path}.part');
    try {
      await _dio.download(
        url,
        partial.path,
        onReceiveProgress: onReceiveProgress,
      );
      await partial.rename(target.path);
      final index = await _loadIndex();
      final meta =
          metadata ??
          OfflineTrackMeta(musicId: musicId, title: 'Hino #$musicId');
      index[_key(musicId, instrumental)] = {
        'path': target.path,
        ...meta.toJson(),
      };
      await _persistIndex();
      return target.path;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  /// Atualiza metadados de uma faixa já baixada. Não baixa nem toca rede.
  Future<void> saveMetadata(OfflineTrackMeta meta) async {
    final index = await _loadIndex();
    final key = _key(meta.musicId, meta.instrumental);
    final path = _pathOf(key, index[key]);
    if (path == null || !await File(path).exists()) return;
    index[key] = {'path': path, ...meta.toJson()};
    await _persistIndex();
  }

  /// Lista faixas baixadas (todas ou de um álbum). Lê o índice em disco —
  /// funciona SEM internet e SEM a API.
  Future<List<OfflineTrack>> listDownloaded({int? albumId}) async {
    final index = await _loadIndex();
    final tracks = <OfflineTrack>[];
    final stale = <String>[];
    for (final entry in index.entries) {
      final path = _pathOf(entry.key, entry.value);
      if (path == null) continue;
      if (!await File(path).exists()) {
        stale.add(entry.key);
        continue;
      }
      final musicId = _musicIdOf(entry.key);
      if (musicId == null) continue;
      OfflineTrackMeta? meta;
      if (entry.value is Map<String, dynamic>) {
        meta = OfflineTrackMeta.fromJson(musicId, entry.value);
      }
      if (albumId != null && meta?.albumId != albumId) continue;
      tracks.add(OfflineTrack(musicId: musicId, path: path, meta: meta));
    }
    if (stale.isNotEmpty) {
      stale.forEach(index.remove);
      await _persistIndex();
    }
    return tracks;
  }

  int? _musicIdOf(String key) => int.tryParse(key.split('_').first);

  Future<void> remove(int musicId, {bool instrumental = false}) async {
    final index = await _loadIndex();
    final key = _key(musicId, instrumental);
    final path = _pathOf(key, index.remove(key));
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _persistIndex();
  }

  String _key(int musicId, bool instrumental) =>
      '${musicId}_${instrumental ? 'instrumental' : 'vocal'}';
}
