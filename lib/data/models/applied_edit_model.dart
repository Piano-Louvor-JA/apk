/// DTO do edit `applied` (aprovado pelo concilio) — portação APK read-only.
/// Paridade com edit-resolver do desktop (app#575): aplicar letra/timing por
/// cima do hino oficial PRESERVANDO metadados (RF-01/RF-08); campo null não
/// apaga o conteúdo oficial (edit parcial); JSON inválido → oficial intacta.
library;
import 'dart:convert';

class AppliedEditModel {
  final int musicId;
  final String? lyrics;
  final String? timing;

  const AppliedEditModel({
    required this.musicId,
    this.lyrics,
    this.timing,
  });

  factory AppliedEditModel.fromJson(Map<String, dynamic> json) =>
      AppliedEditModel(
        musicId: (json['musicId'] ?? json['music_id']) as int,
        lyrics: json['lyrics'] as String?,
        timing: json['timing'] as String?,
      );

  /// Aplica o edit por cima do JSON do hino oficial. Retorna uma CÓPIA com
  /// `lyric` substituída somente se o edit tiver letra válida (JSON parseável).
  Map<String, dynamic> applyToHymnJson(Map<String, dynamic> hymnJson) {
    if (lyrics == null || lyrics!.isEmpty) return hymnJson;
    try {
      final decoded = jsonDecode(lyrics!);
      if (decoded is! List) return hymnJson;
      return {...hymnJson, 'lyric': lyrics};
    } catch (_) {
      return hymnJson;
    }
  }
}

/// Resumo do edit do autor (RF-05) — tela Minhas Edições read-only.
class MyEditSummary {
  final int id;
  final int musicId;
  final String status; // published | approved | rejected
  final String? reason;

  const MyEditSummary({
    required this.id,
    required this.musicId,
    required this.status,
    this.reason,
  });

  factory MyEditSummary.fromJson(Map<String, dynamic> json) => MyEditSummary(
        id: json['id'] as int,
        musicId: json['music_id'] as int,
        status: json['status'] as String,
        reason: json['reason'] as String?,
      );
}
