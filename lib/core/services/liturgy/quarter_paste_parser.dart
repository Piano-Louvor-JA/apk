class QuarterPasteEntry {
  const QuarterPasteEntry({
    required this.slotKey,
    required this.name,
    this.musicId,
    this.filePath,
  });
  final String slotKey;
  final String name;
  final int? musicId;
  final String? filePath;
}

class QuarterPasteGroup {
  QuarterPasteGroup(this.date) : entries = [];
  final DateTime date;
  final List<QuarterPasteEntry> entries;
}

class QuarterPasteResult {
  const QuarterPasteResult(this.groups, this.errors);
  final List<QuarterPasteGroup> groups;
  final List<String> errors;
}

/// Contrato quarter-paste-parser.ts: blocos de data e linhas data — conteúdo.
abstract final class QuarterPasteParser {
  static DateTime? _date(String day, String month, String? rawYear, int year) {
    final y = rawYear == null ? year : int.parse(rawYear);
    final actualYear = y < 100 ? 2000 + y : y;
    final d = int.parse(day);
    final m = int.parse(month);
    final date = DateTime(actualYear, m, d);
    return date.year == actualYear && date.month == m && date.day == d
        ? date
        : null;
  }

  static QuarterPasteEntry? _content(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    var slot = 'item';
    final prefix = RegExp(r'^([^:：]{1,24})[:：]\s*(.*)$').firstMatch(text);
    if (prefix != null &&
        RegExp(r'^[A-Za-zÀ-ÿ0-9 _-]+$').hasMatch(prefix[1]!)) {
      slot = prefix[1]!.trim().toLowerCase();
      text = prefix[2]!.trim();
    }
    text = text.replaceFirst(RegExp(r'^hino\s+', caseSensitive: false), '');
    final fields = text
        .split(RegExp(r'\s+[-—|]+\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (fields.isEmpty) return null;
    final match = RegExp(r'^\d+').firstMatch(fields.first);
    final number = match == null ? null : int.tryParse(match[0]!);
    if (number != null && number > 0)
      return QuarterPasteEntry(
        slotKey: slot,
        musicId: number,
        name: fields.skip(1).join(' - '),
      );
    return QuarterPasteEntry(
      slotKey: slot,
      name: fields.join(' - '),
      filePath: text,
    );
  }

  static QuarterPasteResult parse(String text, {required int year}) {
    final groups = <QuarterPasteGroup>[];
    final errors = <String>[];
    QuarterPasteGroup? current;
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final date = RegExp(
        r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\s*$',
      ).firstMatch(line);
      if (date != null) {
        final value = _date(date[1]!, date[2]!, date[3], year);
        if (value == null) {
          errors.add(line);
          current = null;
        } else {
          current = QuarterPasteGroup(value);
          groups.add(current);
        }
        continue;
      }
      final single = RegExp(
        r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\s+[-—|]+\s+(.+)$',
      ).firstMatch(line);
      if (single != null) {
        final value = _date(single[1]!, single[2]!, single[3], year);
        if (value == null) {
          errors.add(line);
          continue;
        }
        final entry = _content(single[4]!);
        if (entry != null)
          groups.add(QuarterPasteGroup(value)..entries.add(entry));
        continue;
      }
      if (current == null) {
        errors.add(line);
      } else {
        final entry = _content(line);
        if (entry != null) current.entries.add(entry);
      }
    }
    return QuarterPasteResult(groups, errors);
  }
}
