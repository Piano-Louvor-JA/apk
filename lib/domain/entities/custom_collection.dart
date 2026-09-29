import 'package:flutter/foundation.dart';

/// Coletânea custom da comunidade (v1 — leitura/download no APK).
@immutable
class CustomCollection {
  final int id;
  final String name;
  final String? description;
  final String? authorName;
  final String? coverUrl;
  final int musicsCount;

  /// True se a sessão local é dona (futuro: edição no APK).
  final bool isOwner;

  const CustomCollection({
    required this.id,
    required this.name,
    this.description,
    this.authorName,
    this.coverUrl,
    this.musicsCount = 0,
    this.isOwner = false,
  });
}

/// Estrofe de letra custom com timing.
@immutable
class CustomLyricLine {
  final int id;
  final String text;
  final String? auxText;
  final String time;
  final int order;
  final String? imageUrl;

  const CustomLyricLine({
    required this.id,
    required this.text,
    this.auxText,
    required this.time,
    this.order = 0,
    this.imageUrl,
  });
}

/// Música custom detalhada (com lyrics).
@immutable
class CustomMusicDetail {
  final int id;
  final int collectionId;
  final String name;
  final int? durationMs;
  final String? audioUrl;
  final String? instrumentalUrl;
  final List<CustomLyricLine> lyrics;

  const CustomMusicDetail({
    required this.id,
    required this.collectionId,
    required this.name,
    this.durationMs,
    this.audioUrl,
    this.instrumentalUrl,
    this.lyrics = const [],
  });
}
