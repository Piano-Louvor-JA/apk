library;

import 'package:flutter/foundation.dart';

import 'album.dart';

/// Categoria de coletâneas (ex: "Hinário Adventista", "Louvor JA").
///
/// Fonte: API.md — Category.
@immutable
class AlbumCategory {
  final int id;
  final String? name;
  final List<Album> albums;

  const AlbumCategory({required this.id, this.name, this.albums = const []});

  factory AlbumCategory.fromJson(Map<String, dynamic> json) {
    final albumsRaw = json['albums'] as List<dynamic>?;
    return AlbumCategory(
      id: _parseInt(json['id_category']),
      name: json['name'] as String?,
      albums:
          albumsRaw
              ?.map((a) => Album.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id_category': id,
    if (name != null) 'name': name,
    'albums': albums.map((a) => a.toJson()).toList(),
  };

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlbumCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AlbumCategory(id: $id, name: $name, ${albums.length} albums)';
}
