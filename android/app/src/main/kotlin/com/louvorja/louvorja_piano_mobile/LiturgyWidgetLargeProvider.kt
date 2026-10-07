package com.louvorja.louvorja_piano_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

/** 4x2 timeline. Local time determines AGORA; done never does. */
class LiturgyWidgetLargeProvider : AppWidgetProvider() {
    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val ITEMS_PREFIX = "flutter.liturgy_items_"
        const val ACTION_UPDATE = "com.louvorja.louvorja_piano_mobile.ACTION_WIDGET_LARGE"
        private const val MUTED = "#BFC7D4"; private const val CURRENT = "#F8C800"; private const val NEXT = "#78D6D2"
    }
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) = ids.forEach { update(c, m, it) }
    override fun onReceive(c: Context, i: Intent) { super.onReceive(c, i); if (i.action == ACTION_UPDATE) { val m = AppWidgetManager.getInstance(c); onUpdate(c, m, m.getAppWidgetIds(android.content.ComponentName(c, javaClass))) } }
    private fun key(): String { val d = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) % 7; return "$ITEMS_PREFIX${arrayOf("sunday","monday","tuesday","wednesday","thursday","friday","saturday")[d]}" }
    private fun update(c: Context, m: AppWidgetManager, id: Int) {
        val v = RemoteViews(c.packageName, R.layout.liturgy_widget_large); launch(c, v)
        val now = Calendar.getInstance(); val raw = c.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getString(key(), null)
        val snapshot = raw?.let(::parse)?.let { LiturgyTimeline.at(it, now.get(Calendar.HOUR_OF_DAY), now.get(Calendar.MINUTE)) }
        if (snapshot == null || snapshot.items.isEmpty()) { empty(v, "Sem liturgia hoje"); m.updateAppWidget(id, v); return }
        val current = snapshot.current; val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        v.setTextViewText(R.id.liturgy_widget_title, "LITURGIA DE HOJE")
        v.setTextViewText(R.id.liturgy_widget_progress, current?.let { "AGORA · termina em ${it.minutesRemaining} min · ${it.progressPercent}%" } ?: snapshot.next?.let { "PRÓXIMO · ${it.interval}" } ?: "Liturgia encerrada")
        val visible = if (current != null) snapshot.items.filter { it.endMinute != null && it.endMinute <= current.startMinute!! }.takeLast(1) + current + snapshot.items.filter { it.startMinute != null && it.startMinute >= current.endMinute!! }.take(2) else snapshot.items.filter { it.startMinute != null }.take(4)
        val rows = listOf(R.id.liturgy_widget_item1, R.id.liturgy_widget_item2, R.id.liturgy_widget_item3, R.id.liturgy_widget_item4)
        rows.forEachIndexed { n, row -> visible.getOrNull(n)?.let { item ->
            val active = item == current; val future = item.startMinute != null && item.startMinute > minute
            v.setTextViewText(row, "${if (active) "● AGORA" else "●"} ${item.interval ?: "Sem horário"} · ${item.name}")
            v.setTextColor(row, Color.parseColor(if (active) CURRENT else if (future) NEXT else MUTED)); v.setViewVisibility(row, View.VISIBLE)
        } ?: v.setViewVisibility(row, View.GONE) }
        val focus = current ?: snapshot.next
        v.setTextViewText(R.id.liturgy_widget_next, focus?.let { "${it.interval} · ${it.name}" } ?: "")
        v.setTextColor(R.id.liturgy_widget_next, Color.parseColor(if (current != null) CURRENT else NEXT)); v.setViewVisibility(R.id.liturgy_widget_next, if (focus == null) View.GONE else View.VISIBLE)
        m.updateAppWidget(id, v)
    }
    private fun parse(raw: String): List<LiturgyTimeline.Item> = try { JSONArray(raw).let { a -> List(a.length()) { n -> a.getJSONObject(n).let { LiturgyTimeline.Item(it.optString("name", "Item"), it.optString("startTime").ifBlank { null }, it.optString("endTime").ifBlank { null }) } } } } catch (_: Exception) { emptyList() }
    private fun empty(v: RemoteViews, text: String) { v.setTextViewText(R.id.liturgy_widget_title, text); v.setTextViewText(R.id.liturgy_widget_progress, ""); listOf(R.id.liturgy_widget_item1,R.id.liturgy_widget_item2,R.id.liturgy_widget_item3,R.id.liturgy_widget_item4,R.id.liturgy_widget_next).forEach { v.setViewVisibility(it, View.GONE) } }
    private fun launch(c: Context, v: RemoteViews) { c.packageManager.getLaunchIntentForPackage(c.packageName)?.let { v.setOnClickPendingIntent(R.id.liturgy_widget_root, PendingIntent.getActivity(c,0,it,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)) } }
}
