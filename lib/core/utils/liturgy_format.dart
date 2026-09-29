library;

/// Utilidades de formatacao de liturgia (alinhado com Electron liturgy-format.ts).
abstract final class LiturgyFormat {
  /// Padding 2 digitos.
  static String pad2(int value) => value.toString().padLeft(2, '0');

  /// Formata duracao em ms para HH:MM:SS.
  static String formatElapsed(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 999999999);
    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;
    return '${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)}';
  }

  /// Label de duracao: "—" se 0, senao HH:MM:SS.
  static String formatDurationLabel(int? ms) {
    if (ms == null || ms <= 0) return '\u2014';
    return formatElapsed(ms);
  }

  /// Normaliza horario HH:MM (aceita HH:MM:SS).
  static String? normalizeTimeHHmm(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null || minutes == null) return null;
    if (hours > 23 || minutes > 59) return null;
    return '${pad2(hours)}:${pad2(minutes)}';
  }
}
