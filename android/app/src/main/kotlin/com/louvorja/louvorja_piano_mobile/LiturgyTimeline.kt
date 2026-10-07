package com.louvorja.louvorja_piano_mobile

/** Pure local-time schedule model shared by both Liturgia widgets. */
object LiturgyTimeline {
    data class Item(val name: String, val start: String?, val end: String?)
    data class Moment(
        val name: String,
        val startMinute: Int?,
        val endMinute: Int?,
        val interval: String?,
        val progressPercent: Int? = null,
        val minutesRemaining: Int? = null,
    )
    data class Snapshot(val items: List<Moment>, val current: Moment?, val next: Moment?)

    fun at(items: List<Item>, hour: Int, minute: Int): Snapshot {
        val now = hour * 60 + minute
        val moments = items.map { item ->
            val start = parse(item.start)
            val end = parse(item.end)
            if (start == null || end == null || end <= start) Moment(item.name, null, null, null)
            else Moment(item.name, start, end, "%02d:%02d–%02d:%02d".format(start / 60, start % 60, end / 60, end % 60))
        }.sortedWith(compareBy<Moment> { it.startMinute == null }.thenBy { it.startMinute ?: Int.MAX_VALUE })
        val currentBase = moments.firstOrNull { it.startMinute != null && now >= it.startMinute && now < it.endMinute!! }
        val current = currentBase?.let {
            it.copy(progressPercent = ((now - it.startMinute!!) * 100 / (it.endMinute!! - it.startMinute)).coerceIn(0, 100), minutesRemaining = it.endMinute - now)
        }
        return Snapshot(moments, current, moments.firstOrNull { it.startMinute != null && now < it.startMinute })
    }

    private fun parse(value: String?): Int? {
        val parts = value?.split(':') ?: return null
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return if (hour in 0..23 && minute in 0..59) hour * 60 + minute else null
    }
}
