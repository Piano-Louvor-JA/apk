library;

import 'package:flutter/foundation.dart';

/// Versão/tradução disponível.
@immutable
class BibleVersion {
  final int id;
  final String abbreviation;
  final String name;
  final String languageId;

  const BibleVersion({
    required this.id,
    required this.abbreviation,
    required this.name,
    this.languageId = 'pt',
  });

  factory BibleVersion.fromJson(Map<String, dynamic> json) {
    return BibleVersion(
      id: _parseInt(json['id_bible_version']),
      abbreviation: (json['abbreviation'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      languageId: (json['id_language'] ?? 'pt').toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'id_bible_version': id,
    'abbreviation': abbreviation,
    'name': name,
    'id_language': languageId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVersion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BibleVersion(id: $id, abbreviation: $abbreviation, name: $name)';
}
