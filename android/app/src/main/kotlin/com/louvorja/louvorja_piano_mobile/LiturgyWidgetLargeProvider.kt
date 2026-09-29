package com.louvorja.louvorja_piano_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/// Widget de liturgia 4x2: mostra até 4 próximos itens + próximo destaque.
class LiturgyWidgetLargeProvider : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val ITEMS_PREFIX = "flutter.liturgy_items_"
        const val ACTION_UPDATE = "com.louvorja.louvorja_piano_mobile.ACTION_WIDGET_LARGE"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, LiturgyWidgetLargeProvider::class.java)
            )
            for (id in ids) update(context, mgr, id)
        }
    }

    private fun todayKey(): String {
        val d = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) % 7
        val days = arrayOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
        return "$ITEMS_PREFIX${days[d]}"
    }

    private fun update(context: Context, mgr: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(todayKey(), null)
        val views = RemoteViews(context.packageName, R.layout.liturgy_widget_large)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pi = launchIntent?.let {
            PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        if (pi != null) views.setOnClickPendingIntent(R.id.liturgy_widget_root, pi)

        if (raw == null) {
            views.setTextViewText(R.id.liturgy_widget_title, "Sem liturgia hoje")
            views.setTextViewText(R.id.liturgy_widget_progress, "")
            for (i in 1..4) views.setViewVisibility(
                context.resources.getIdentifier("liturgy_widget_item$i", "id", context.packageName),
                View.GONE
            )
            views.setViewVisibility(R.id.liturgy_widget_next, View.GONE)
            mgr.updateAppWidget(id, views)
            return
        }

        val items = parseItems(raw)
        if (items.isEmpty()) {
            views.setTextViewText(R.id.liturgy_widget_title, "Sem itens")
            views.setTextViewText(R.id.liturgy_widget_progress, "")
            for (i in 1..4) views.setViewVisibility(
                context.resources.getIdentifier("liturgy_widget_item$i", "id", context.packageName),
                View.GONE
            )
            views.setViewVisibility(R.id.liturgy_widget_next, View.GONE)
            mgr.updateAppWidget(id, views)
            return
        }

        val done = items.count { it.optBoolean("done", false) }
        val total = items.size
        val title = items[0].optString("name", "Liturgia")
        views.setTextViewText(R.id.liturgy_widget_title, title)
        views.setTextViewText(R.id.liturgy_widget_progress, "$done/$total")

        // Próximos 4 itens pendentes (ou marcados como feitos com ✓)
        val pending = items.filter { !it.optBoolean("done", false) }
        val itemIds = listOf(
            R.id.liturgy_widget_item1,
            R.id.liturgy_widget_item2,
            R.id.liturgy_widget_item3,
            R.id.liturgy_widget_item4,
        )

        for (i in 0 until 4) {
            val itemId = itemIds[i]
            if (i < pending.size) {
                val item = pending[i]
                views.setTextViewText(itemId, item.optString("name", ""))
                views.setViewVisibility(itemId, View.VISIBLE)
            } else if (i < pending.size + 2 && i - pending.size < items.size) {
                // Mostra últimos feitos com ✓ se sobrou espaço
                val doneItem = items.filter { it.optBoolean("done", false) }.getOrNull(i - pending.size)
                if (doneItem != null) {
                    views.setTextViewText(itemId, "✓ ${doneItem.optString("name", "")}")
                    views.setViewVisibility(itemId, View.VISIBLE)
                } else {
                    views.setViewVisibility(itemId, View.GONE)
                }
            } else {
                views.setViewVisibility(itemId, View.GONE)
            }
        }

        // Próximo destaque
        val next = pending.firstOrNull()
        if (next != null) {
            views.setTextViewText(R.id.liturgy_widget_next, "▶ ${next.optString("name", "")}")
            views.setViewVisibility(R.id.liturgy_widget_next, View.VISIBLE)
        } else {
            views.setTextViewText(R.id.liturgy_widget_next, "✓ Concluída")
            views.setViewVisibility(R.id.liturgy_widget_next, View.VISIBLE)
        }

        mgr.updateAppWidget(id, views)
    }

    private fun parseItems(raw: String): List<JSONObject> = try {
        val arr = JSONArray(raw)
        (0 until arr.length()).map { arr.getJSONObject(it) }
    } catch (_: Exception) { emptyList() }
}
