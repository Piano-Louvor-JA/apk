library;

import 'package:flutter/widgets.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Dias da semana para liturgia.
enum LiturgyWeekday {
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
}

extension LiturgyWeekdayJa on LiturgyWeekday {
  /// Dia do formato .ja do Delphi (1=domingo .. 7=sábado).
  /// Confirmedo no fonte Delphi: NOMES_DIAS[1]='Domingo'...[7]='Sábado'
  /// (fmCopiaLiturgiaDia.pas). Chave 7 = Escola Sabatina (sábado manhã).
  static LiturgyWeekday? fromJaDay(int day) => switch (day) {
    1 => LiturgyWeekday.sunday,
    2 => LiturgyWeekday.monday,
    3 => LiturgyWeekday.tuesday,
    4 => LiturgyWeekday.wednesday,
    5 => LiturgyWeekday.thursday,
    6 => LiturgyWeekday.friday,
    7 => LiturgyWeekday.saturday,
    _ => null,
  };
}

/// Ordem das tabs: dom, seg, ter, qua, qui, sex, sab.
const liturgyDayTabOrder = [
  LiturgyWeekday.sunday,
  LiturgyWeekday.monday,
  LiturgyWeekday.tuesday,
  LiturgyWeekday.wednesday,
  LiturgyWeekday.thursday,
  LiturgyWeekday.friday,
  LiturgyWeekday.saturday,
];

/// Tipos de item da liturgia, alinhados ao módulo Electron/web.
enum LiturgyItemType {
  category,
  music,
  annotation,
  notice,
  scheduled,
  prayer,
  video,
  images,
  pdf,
  presentation,
  otherFiles,
  onlineVideo,
  site,
  verse,
}

/// Metadata visual de cada tipo (cor + nome do icone Tabler).
class LiturgyItemTypeMeta {
  final LiturgyItemType value;
  final int colorValue;
  final IconData icon;

  const LiturgyItemTypeMeta({
    required this.value,
    required this.colorValue,
    required this.icon,
  });

  Color get color => Color(colorValue);
}

/// Tabela de tipos -> metadata visual (alinhado com Electron).
@immutable
class LiturgyTypeRegistry {
  static const _meta = {
    LiturgyItemType.category: LiturgyItemTypeMeta(
      value: LiturgyItemType.category,
      colorValue: 0xFFFFD600,
      icon: TablerIcons.tag,
    ),
    LiturgyItemType.music: LiturgyItemTypeMeta(
      value: LiturgyItemType.music,
      colorValue: 0xFF00E676,
      icon: TablerIcons.music,
    ),
    LiturgyItemType.annotation: LiturgyItemTypeMeta(
      value: LiturgyItemType.annotation,
      colorValue: 0xFFFF6D00,
      icon: TablerIcons.textCaption,
    ),
    LiturgyItemType.notice: LiturgyItemTypeMeta(
      value: LiturgyItemType.notice,
      colorValue: 0xFFFFD600,
      icon: TablerIcons.speakerphone,
    ),
    LiturgyItemType.scheduled: LiturgyItemTypeMeta(
      value: LiturgyItemType.scheduled,
      colorValue: 0xFF00BCD4,
      icon: TablerIcons.calendarTime,
    ),
    LiturgyItemType.prayer: LiturgyItemTypeMeta(
      value: LiturgyItemType.prayer,
      colorValue: 0xFF42A5F5,
      icon: TablerIcons.pray,
    ),
    LiturgyItemType.video: LiturgyItemTypeMeta(
      value: LiturgyItemType.video,
      colorValue: 0xFF00B8D4,
      icon: TablerIcons.video,
    ),
    LiturgyItemType.images: LiturgyItemTypeMeta(
      value: LiturgyItemType.images,
      colorValue: 0xFF6D4C41,
      icon: TablerIcons.photo,
    ),
    LiturgyItemType.pdf: LiturgyItemTypeMeta(
      value: LiturgyItemType.pdf,
      colorValue: 0xFF1A237E,
      icon: TablerIcons.fileTypePdf,
    ),
    LiturgyItemType.presentation: LiturgyItemTypeMeta(
      value: LiturgyItemType.presentation,
      colorValue: 0xFFF5F5F5,
      icon: TablerIcons.fileTypePpt,
    ),
    LiturgyItemType.otherFiles: LiturgyItemTypeMeta(
      value: LiturgyItemType.otherFiles,
      colorValue: 0xFF00BCD4,
      icon: TablerIcons.files,
    ),
    LiturgyItemType.onlineVideo: LiturgyItemTypeMeta(
      value: LiturgyItemType.onlineVideo,
      colorValue: 0xFF2979FF,
      icon: TablerIcons.brandYoutube,
    ),
    LiturgyItemType.site: LiturgyItemTypeMeta(
      value: LiturgyItemType.site,
      colorValue: 0xFFAEEA00,
      icon: TablerIcons.world,
    ),
    LiturgyItemType.verse: LiturgyItemTypeMeta(
      value: LiturgyItemType.verse,
      colorValue: 0xFFAB47BC,
      icon: TablerIcons.book,
    ),
  };

  static LiturgyItemTypeMeta metaFor(LiturgyItemType type) {
    return _meta[type]!;
  }

  static Color colorFor(LiturgyItemType type) => metaFor(type).color;

  static IconData iconFor(LiturgyItemType type) => metaFor(type).icon;

  static List<LiturgyItemType> get allTypes => _meta.keys.toList();
}

/// Item de liturgia (momento do culto).
@immutable
class LiturgyItem {
  final String id;
  final LiturgyItemType type;
  final String name;
  final String subtitle;
  final bool done;
  final int durationMs;
  final String accentColor;
  final String? categoryId;
  final String? notes;
  final int? musicId;
  final String? musicMode;
  final int? verseBookId;
  final int? verseChapter;
  final String? verseNumbers;
  final String? filePath;
  final List<String> filePaths;
  final String? url;

  /// Data/hora ISO 8601 do item agendado, quando type == scheduled.
  final String? scheduledAt;
  final String? startTime;
  final String? endTime;

  const LiturgyItem({
    required this.id,
    required this.type,
    required this.name,
    this.subtitle = '',
    this.done = false,
    this.durationMs = 0,
    this.accentColor = '',
    this.categoryId,
    this.notes,
    this.musicId,
    this.musicMode,
    this.verseBookId,
    this.verseChapter,
    this.verseNumbers,
    this.filePath,
    this.filePaths = const [],
    this.url,
    this.scheduledAt,
    this.startTime,
    this.endTime,
  });

  LiturgyItem copyWith({
    String? id,
    LiturgyItemType? type,
    String? name,
    String? subtitle,
    bool? done,
    int? durationMs,
    String? accentColor,
    String? categoryId,
    String? notes,
    int? musicId,
    String? musicMode,
    int? verseBookId,
    int? verseChapter,
    String? verseNumbers,
    String? filePath,
    List<String>? filePaths,
    String? url,
    String? scheduledAt,
    String? startTime,
    String? endTime,
  }) {
    return LiturgyItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      done: done ?? this.done,
      durationMs: durationMs ?? this.durationMs,
      accentColor: accentColor ?? this.accentColor,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      musicId: musicId ?? this.musicId,
      musicMode: musicMode ?? this.musicMode,
      verseBookId: verseBookId ?? this.verseBookId,
      verseChapter: verseChapter ?? this.verseChapter,
      verseNumbers: verseNumbers ?? this.verseNumbers,
      filePath: filePath ?? this.filePath,
      filePaths: filePaths ?? this.filePaths,
      url: url ?? this.url,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': _typeToWire(type),
    'name': name,
    'subtitle': subtitle,
    'done': done,
    'durationMs': durationMs,
    'accentColor': accentColor,
    if (categoryId != null) 'categoryId': categoryId,
    if (notes != null) 'notes': notes,
    if (musicId != null) 'musicId': musicId,
    if (musicMode != null) 'musicMode': musicMode,
    if (verseBookId != null) 'verseBookId': verseBookId,
    if (verseChapter != null) 'verseChapter': verseChapter,
    if (verseNumbers != null) 'verseNumbers': verseNumbers,
    if (filePath != null) 'filePath': filePath,
    if (filePaths.isNotEmpty) 'filePaths': filePaths,
    if (url != null) 'url': url,
    if (scheduledAt != null) 'scheduledAt': scheduledAt,
    if (startTime != null) 'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
  };

  factory LiturgyItem.fromJson(Map<String, dynamic> json) {
    return LiturgyItem(
      id: json['id'] as String? ?? '',
      type: _typeFromWire(json['type'] as String? ?? 'annotation'),
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      accentColor: json['accentColor'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      notes: json['notes'] as String?,
      musicId: (json['musicId'] as num?)?.toInt(),
      musicMode: json['musicMode'] as String?,
      verseBookId: (json['verseBookId'] as num?)?.toInt(),
      verseChapter: (json['verseChapter'] as num?)?.toInt(),
      verseNumbers: json['verseNumbers'] as String?,
      filePath: json['filePath'] as String?,
      filePaths:
          (json['filePaths'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
      url: json['url'] as String?,
      scheduledAt: json['scheduledAt'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
    );
  }

  static String _typeToWire(LiturgyItemType type) => switch (type) {
    LiturgyItemType.otherFiles => 'other_files',
    LiturgyItemType.onlineVideo => 'online_video',
    _ => type.name,
  };

  static LiturgyItemType _typeFromWire(String value) => switch (value) {
    'other_files' => LiturgyItemType.otherFiles,
    'online_video' => LiturgyItemType.onlineVideo,
    _ => LiturgyItemType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LiturgyItemType.annotation,
    ),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LiturgyItem && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'LiturgyItem(id: $id, type: $type, name: $name, done: $done)';
}
