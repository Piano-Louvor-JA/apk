library;

import 'package:flutter/foundation.dart';

/// Hino do catálogo LouvorJA.
///
/// Fonte: API.md — HymnalRow / MusicIndexRow.
/// A duração vem em 3 formatos possíveis do JSON; [parseDurationMs] normaliza.
@immutable
class Hymn {
  final int id;
  final String? title;
  final int? number;
  final int? durationMs;
  final bool hasInstrumental;
  final String? urlMusic;
  final String? urlInstrumental;
  final String? lyric;

  /// Lyric estruturado (endpoint music_{id}): slides com times e imagens.
  /// Catálogo (lista) não traz — null nesse caso.
  final List<Map<String, dynamic>>? lyricRaw;

  /// Imagem de capa da música (url_image do detail).
  final String? imageUrl;

  const Hymn({
    required this.id,
    this.title,
    this.number,
    this.durationMs,
    this.hasInstrumental = false,
    this.urlMusic,
    this.urlInstrumental,
    this.lyric,
    this.lyricRaw,
    this.imageUrl,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) {
    return Hymn(
      id: _parseInt(json['id_music']),
      title: json['name'] as String?,
      number: _parseNullableInt(json['track']),
      durationMs: parseDurationMs(json['duration']),
      hasInstrumental: _parseBool(json['has_instrumental_music']),
      urlMusic: json['url_music'] as String?,
      urlInstrumental: json['url_instrumental_music'] as String?,
      lyric: _parseLyric(json['lyric']),
      lyricRaw: json['lyric'] is List
          ? (json['lyric'] as List)
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList()
          : null,
      imageUrl: json['url_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_music': id,
    if (title != null) 'name': title,
    if (number != null) 'track': number,
    if (durationMs != null) 'duration': durationMs,
    'has_instrumental_music': hasInstrumental ? 1 : 0,
    if (urlMusic != null) 'url_music': urlMusic,
    if (urlInstrumental != null) 'url_instrumental_music': urlInstrumental,
    if (lyric != null) 'lyric': lyric,
  };

  /// Formata duração em "M:SS" ou "H:MM:SS".
  String get formattedDuration {
    final ms = durationMs;
    if (ms == null) return '';
    final totalSec = ms ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0)
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Parser de duração que aceita os 3 formatos do API:
  /// 1. number (segundos): 187.5 → 187500 ms
  /// 2. "MM:SS": "3:07" → 187000 ms
  /// 3. "HH:MM:SS": "1:02:03" → 3723000 ms
  static int? parseDurationMs(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      return (raw * 1000).round();
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      // Tenta parse como número (segundos)
      final asNum = num.tryParse(trimmed);
      if (asNum != null) return (asNum * 1000).round();

      // Formato MM:SS ou HH:MM:SS
      final parts = trimmed.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]);
        final s = int.tryParse(parts[1]);
        if (m != null && s != null) return (m * 60 + s) * 1000;
      }
      if (parts.length == 3) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final s = int.tryParse(parts[2]);
        if (h != null && m != null && s != null) {
          return (h * 3600 + m * 60 + s) * 1000;
        }
      }
    }

    return null;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _parseNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  /// A API pode retornar a letra como texto unico (catalogo) ou uma lista
  /// ordenada de estrofes (endpoint music_{id}). Normaliza ambos para texto.
  static String? _parseLyric(dynamic raw) {
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is! List) return null;

    final verses =
        raw
            .whereType<Map>()
            .map(
              (entry) => {
                'order': _parseInt(entry['order']),
                'show': _parseBool(entry['show_slide']),
                'text': (entry['lyric'] ?? '').toString().trim(),
              },
            )
            .where(
              (entry) =>
                  entry['show'] == true && (entry['text'] as String).isNotEmpty,
            )
            .toList()
          ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

    if (verses.isEmpty) return null;
    return verses.map((entry) => entry['text'] as String).join('\n\n');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hymn && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Hymn(id: $id, number: $number, title: $title)';
}
