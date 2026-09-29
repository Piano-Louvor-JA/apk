package com.louvorja.louvorja_piano_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/// Widget de liturgia: 4x1 compacto.
///
/// Lê SharedPreferences (mesma chave do Dart) e mostra:
/// - título do primeiro item (nome do culto/hinário do dia)
/// - próximo item pendente (▶ nome)
/// - progresso (feitos/total)
///
/// Atualiza a cada 5 min (XML) + quando o app salva liturgia.
class LiturgyWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val ITEMS_PREFIX = "flutter.liturgy_items_"
        const val WIDGET_TITLE = "com.louvorja.louvorja_piano_mobile.ACTION_WIDGET_TITLE"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) updateAppWidget(context, appWidgetManager, id)
    }

    override fun onEnabled(context: Context) {}

    override fun onDisabled(context: Context) {}

    /// Quando o app salva a liturgia, envia broadcast pra atualizar o widget.
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WIDGET_TITLE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, LiturgyWidgetProvider::class.java)
            )
            for (id in ids) updateAppWidget(context, mgr, id)
        }
    }

    private fun todayKey(): String {
        val dayOfWeek = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) // 1=dom..7=sab
        val index = dayOfWeek % 7 // 0=dom, 1=seg..6=sab
        val days = arrayOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
        return "$ITEMS_PREFIX${days[index]}"
    }

    private fun updateAppWidget(context: Context, mgr: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(todayKey(), null) ?: run {
            setEmptyView(context, mgr, id, "Sem liturgia hoje")
            return
        }

        val items = parseItems(raw)
        if (items.isEmpty()) {
            setEmptyView(context, mgr, id, "Sem itens")
            return
        }

        val done = items.count { it.optBoolean("done", false) }
        val total = items.size
        val next = items.firstOrNull { !it.optBoolean("done", false) }

        // Título: primeiro item (geralmente nome da categoria/hinário)
        val title = items[0].optString("name", "Liturgia")

        val views = RemoteViews(context.packageName, R.layout.liturgy_widget)
        views.setTextViewText(R.id.liturgy_widget_title, title)
        views.setTextViewText(R.id.liturgy_widget_progress, "$done/$total")

        if (next != null) {
            views.setTextViewText(R.id.liturgy_widget_next, "▶ ${next.optString("name", "")}")
            views.setViewVisibility(R.id.liturgy_widget_next, View.VISIBLE)
        } else {
            views.setTextViewText(R.id.liturgy_widget_next, "✓ Concluída")
            views.setViewVisibility(R.id.liturgy_widget_next, View.VISIBLE)
        }

        // Tap abre o app na aba de liturgia
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pi = launchIntent?.let {
            PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        if (pi != null) {
            views.setOnClickPendingIntent(R.id.liturgy_widget_root, pi)
        }

        mgr.updateAppWidget(id, views)
    }

    private fun setEmptyView(context: Context, mgr: AppWidgetManager, id: Int, msg: String) {
        val views = RemoteViews(context.packageName, R.layout.liturgy_widget)
        views.setTextViewText(R.id.liturgy_widget_title, msg)
        views.setTextViewText(R.id.liturgy_widget_next, "")
        views.setTextViewText(R.id.liturgy_widget_progress, "")
        views.setViewVisibility(R.id.liturgy_widget_next, View.GONE)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pi = launchIntent?.let {
            PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        if (pi != null) views.setOnClickPendingIntent(R.id.liturgy_widget_root, pi)
        mgr.updateAppWidget(id, views)
    }

    private fun parseItems(raw: String): List<JSONObject> {
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getJSONObject(it) }
        } catch (_: Exception) { emptyList() }
    }
}