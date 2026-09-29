library;

import 'dart:convert';

/// Pacote de sincronização LouvorJA — formato ÚNICO entre
/// Desktop (Electron), Web e Mobile (APK).
///
/// Camada 3 da SPEC-SYNC: arquivo `.louvorja` (JSON gzip em disco;
/// JSON puro em memória/testes). Cross-version: o [schemaVersion]
/// permite evoluir o formato sem quebrar importações antigas.
///
/// Conflitos: last-write-wins por entidade (decisão da SPEC).
class SyncPackage {
  static const int schemaVersion = 1;

  final String appVersion;
  final String platform;
  final DateTime exportedAt;

  /// Entidades sincronizáveis. Chave = nome estável da entidade.
  final Map<String, SyncEntity> entities;

  const SyncPackage({
    required this.appVersion,
    required this.platform,
    required this.exportedAt,
    this.entities = const {},
  });

  /// Liturgia do pacote (atalho).
  SyncEntity? get liturgy => entities['liturgy'];

  SyncPackage copyWith({
    String? appVersion,
    String? platform,
    DateTime? exportedAt,
    Map<String, SyncEntity>? entities,
  }) => SyncPackage(
    appVersion: appVersion ?? this.appVersion,
    platform: platform ?? this.platform,
    exportedAt: exportedAt ?? this.exportedAt,
    entities: entities ?? this.entities,
  );

  String encode() => jsonEncode(toJson());

  factory SyncPackage.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['schema'] != schemaVersion) {
      throw const SyncSchemaException();
    }
    final ents = <String, SyncEntity>{};
    final rawEnts = j['entities'] as Map<String, dynamic>? ?? {};
    for (final e in rawEnts.entries) {
      ents[e.key] = SyncEntity.fromJson(e.value as Map<String, dynamic>);
    }
    return SyncPackage(
      appVersion: j['appVersion'] as String? ?? '',
      platform: j['platform'] as String? ?? '',
      exportedAt:
          DateTime.tryParse(j['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entities: ents,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema': schemaVersion,
    'appVersion': appVersion,
    'platform': platform,
    'exportedAt': exportedAt.toIso8601String(),
    'entities': entities.map((k, v) => MapEntry(k, v.toJson())),
  };

  /// Merge LWW: mantém, por entidade, a versão com `modified` mais recente.
  /// Retorna um NOVO pacote (imutável).
  SyncPackage merge(SyncPackage other) {
    final merged = Map<String, SyncEntity>.from(entities);
    for (final e in other.entities.entries) {
      final mine = merged[e.key];
      if (mine == null || e.value.modified.isAfter(mine.modified)) {
        merged[e.key] = e.value;
      }
    }
    return SyncPackage(
      appVersion: appVersion,
      platform: platform,
      exportedAt: DateTime.now().toUtc(),
      entities: merged,
    );
  }
}

/// Uma entidade sincronizável com timestamp de última modificação.
class SyncEntity {
  final String type;
  final DateTime modified;
  final Map<String, dynamic> data;

  const SyncEntity({
    required this.type,
    required this.modified,
    required this.data,
  });

  factory SyncEntity.fromJson(Map<String, dynamic> j) => SyncEntity(
    type: j['type'] as String? ?? '',
    modified:
        DateTime.tryParse(j['modified'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    data: (j['data'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>(),
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'modified': modified.toIso8601String(),
    'data': data,
  };
}

/// Schema incompatível: importador antigo recebeu pacote do futuro.
class SyncSchemaException implements Exception {
  const SyncSchemaException();
  @override
  String toString() => 'Pacote .louvorja com schema incompatível';
}
