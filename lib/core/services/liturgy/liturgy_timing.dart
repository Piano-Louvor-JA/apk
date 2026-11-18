import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_item_rules.dart';
import 'package:louvorja_piano_mobile/core/utils/liturgy_format.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

/// Estimativas e datas dos mesmos contratos liturgy-item-helpers/useLiturgyClock.
abstract final class LiturgyTiming {
  static DateTime activeDate(LiturgyWeekday? day, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final midnight = DateTime(date.year, date.month, date.day);
    return day == null
        ? midnight
        : DateTime(
            date.year,
            date.month,
            date.day + day.index - date.weekday % 7,
          );
  }

  static int? minutes(String? raw) {
    final normalized = LiturgyFormat.normalizeTimeHHmm(raw);
    if (normalized == null) return null;
    final p = normalized.split(':').map(int.parse).toList();
    return p[0] * 60 + p[1];
  }

  static String hhmm(int minutes) {
    final m = minutes % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  static String? categoryEnd(LiturgyItem category, List<LiturgyItem> children) {
    final real = LiturgyFormat.normalizeTimeHHmm(category.endTime);
    if (real != null) return real;
    final start = minutes(category.startTime);
    if (start == null) return null;
    final total = children.fold<int>(
      0,
      (sum, item) => sum + LiturgyItemRules.durationMs(item),
    );
    return total > 0 ? hhmm(start + (total / 60000).ceil()) : null;
  }

  static String? estimatedEnd(List<LiturgyItem> items) {
    var latest = -1;
    String? result;
    for (final cat in items.where((e) => e.type == LiturgyItemType.category)) {
      final end = categoryEnd(
        cat,
        items.where((e) => e.categoryId == cat.id).toList(),
      );
      final m = minutes(end);
      if (m == null) continue;
      final start = minutes(cat.startTime);
      final absolute = m + (start != null && m < start ? 1440 : 0);
      if (absolute > latest) {
        latest = absolute;
        result = end;
      }
    }
    return result;
  }

  static Duration remaining(String endTime, DateTime startedAt, DateTime now) {
    final m = minutes(endTime);
    if (m == null) return Duration.zero;
    final deadline = DateTime(
      startedAt.year,
      startedAt.month,
      startedAt.day,
      m ~/ 60,
      m % 60,
    );
    final left = deadline.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}
