import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/youtube/youtube_file_name.dart';
import 'package:louvorja_piano_mobile/domain/entities/youtube_video.dart';

/// Vídeo baixado pelo módulo YouTube: dados para a aba "Baixados" e o nome
/// do arquivo (`<título>_<id>.mp4`, que o operador pode renomear).
///
/// No celular a cópia fica na pasta interna do app, junto dos vídeos da
/// Liturgia (que a acham pelo endereço do vídeo); por isso o arquivo no
/// disco mantém o nome interno e o nome escolhido fica guardado aqui.
class YoutubeDownloadEntry {
  const YoutubeDownloadEntry({
    required this.video,
    required this.at,
    this.name,
  });

  final YoutubeVideo video;

  /// Quando terminou de baixar (ms).
  final int at;

  /// Nome dado pelo operador (sem extensão), ou nulo = automático.
  final String? name;

  String get videoId => video.videoId;

  /// Nome do arquivo (com `.mp4`).
  String get fileName => '${name ?? youtubeFileBase(video.title, videoId)}.mp4';

  /// O operador deu outro nome (diferente do automático).
  bool get renamed =>
      name != null && name != youtubeFileBase(video.title, videoId);

  YoutubeDownloadEntry copyWith({String? Function()? name}) =>
      YoutubeDownloadEntry(
        video: video,
        at: at,
        name: name != null ? name() : this.name,
      );

  Map<String, dynamic> toJson() => {
    'videoId': video.videoId,
    'title': video.title,
    'channel': video.channel,
    'thumbnail': video.thumbnail,
    'durationText': video.durationText,
    'at': at,
    'name': ?name,
  };

  static final _safeName = RegExp(r'^[A-Za-z0-9 _-]{1,120}$');

  static YoutubeDownloadEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String str(String key) => raw[key] is String ? raw[key] as String : '';
    final id = str('videoId');
    if (!YoutubeVideo.isValidId(id)) return null;
    final name = str('name');
    final at = raw['at'];
    return YoutubeDownloadEntry(
      video: YoutubeVideo(
        videoId: id,
        title: str('title').isEmpty ? id : str('title'),
        channel: str('channel'),
        thumbnail: str('thumbnail'),
        durationText: str('durationText'),
      ),
      at: at is num && at > 0 ? at.toInt() : 0,
      name: _safeName.hasMatch(name) && name.trim() == name ? name : null,
    );
  }
}

/// Registro dos vídeos baixados e da ordem da aba "Baixados".
class YoutubeDownloadIndex {
  YoutubeDownloadIndex({
    Future<SharedPreferences> Function()? prefs,
    int Function()? clock,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final Future<SharedPreferences> Function() _prefs;
  final int Function() _clock;

  static const entriesKey = 'louvorja-youtube-downloads-v1';
  static const orderKey = 'louvorja-youtube-downloads-order-v1';

  Future<List<Object?>> _readList(String key) async {
    final raw = (await _prefs()).getString(key);
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw);
      return data is List ? data : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<YoutubeDownloadEntry>> entries() async {
    final seen = <String>{};
    final list = <YoutubeDownloadEntry>[];
    for (final item in await _readList(entriesKey)) {
      final entry = YoutubeDownloadEntry.fromJson(item);
      if (entry != null && seen.add(entry.videoId)) list.add(entry);
    }
    return list;
  }

  Future<void> _save(List<YoutubeDownloadEntry> list) async => (await _prefs())
      .setString(entriesKey, jsonEncode([for (final e in list) e.toJson()]));

  /// Registra (ou atualiza os dados de) um vídeo baixado; o nome dado
  /// pelo operador é mantido.
  Future<List<YoutubeDownloadEntry>> remember(YoutubeVideo video) async {
    final list = await entries();
    final previous = list.where((e) => e.videoId == video.videoId).firstOrNull;
    final entry = YoutubeDownloadEntry(
      video: YoutubeVideo(
        videoId: video.videoId,
        title: video.title.trim().isEmpty
            ? (previous?.video.title ?? video.videoId)
            : video.title.trim(),
        channel: video.channel.isEmpty
            ? (previous?.video.channel ?? '')
            : video.channel,
        thumbnail: video.thumbnail.isEmpty
            ? (previous?.video.thumbnail ?? '')
            : video.thumbnail,
        durationText: video.durationText.isEmpty
            ? (previous?.video.durationText ?? '')
            : video.durationText,
      ),
      at: previous?.at ?? _clock(),
      name: previous?.name,
    );
    final next = [entry, ...list.where((e) => e.videoId != video.videoId)];
    await _save(next);
    return next;
  }

  /// Renomeia: devolve o nome novo do arquivo (com `.mp4`), ou nulo se o
  /// vídeo não está registrado.
  Future<String?> rename(String videoId, String name) async {
    final list = await entries();
    final index = list.indexWhere((e) => e.videoId == videoId);
    if (index < 0) return null;
    final base = youtubeFileBase(name, videoId);
    final entry = list[index];
    final automatic = youtubeFileBase(entry.video.title, videoId);
    list[index] = entry.copyWith(name: () => base == automatic ? null : base);
    await _save(list);
    return '$base.mp4';
  }

  Future<void> forget(String videoId) async {
    final list = await entries();
    final next = list.where((e) => e.videoId != videoId).toList();
    if (next.length != list.length) await _save(next);
  }

  /// Ordem da aba "Baixados" (IDs).
  Future<List<String>> order() async =>
      (await _readList(orderKey)).whereType<String>().toList();

  Future<void> saveOrder(List<String> ids) async =>
      (await _prefs()).setString(orderKey, jsonEncode(ids));
}
