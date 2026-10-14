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

/** Compact temporal summary: AGORA, otherwise the next scheduled item. */
class LiturgyWidgetProvider : AppWidgetProvider() {
    companion object { const val PREFS_NAME = "FlutterSharedPreferences"; const val ITEMS_PREFIX = "flutter.liturgy_items_"; const val WIDGET_TITLE = "com.louvorja.louvorja_piano_mobile.ACTION_WIDGET_TITLE" }
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) = ids.forEach { update(c,m,it) }
    override fun onReceive(c: Context, i: Intent) { super.onReceive(c,i); if (i.action == WIDGET_TITLE) { val m=AppWidgetManager.getInstance(c); onUpdate(c,m,m.getAppWidgetIds(android.content.ComponentName(c,javaClass))) } }
    private fun key(): String { val d=Calendar.getInstance().get(Calendar.DAY_OF_WEEK)%7; return "$ITEMS_PREFIX${arrayOf("sunday","monday","tuesday","wednesday","thursday","friday","saturday")[d]}" }
    private fun update(c: Context,m: AppWidgetManager,id:Int) {
        val v=RemoteViews(c.packageName,R.layout.liturgy_widget); val now=Calendar.getInstance()
        val raw=c.getSharedPreferences(PREFS_NAME,Context.MODE_PRIVATE).getString(key(),null)
        val snapshot=raw?.let(::parse)?.let { LiturgyTimeline.at(it,now.get(Calendar.HOUR_OF_DAY),now.get(Calendar.MINUTE)) }
        if(snapshot==null || snapshot.items.isEmpty()) { v.setTextViewText(R.id.liturgy_widget_title,"Sem liturgia hoje"); v.setViewVisibility(R.id.liturgy_widget_next,View.GONE); v.setTextViewText(R.id.liturgy_widget_progress,"") }
        else { val focus=snapshot.current?:snapshot.next; v.setTextViewText(R.id.liturgy_widget_title,if(snapshot.current!=null) "AGORA" else "LITURGIA DE HOJE"); v.setTextViewText(R.id.liturgy_widget_next,focus?.let { "${it.interval} · ${it.name}" }?:"Liturgia encerrada"); v.setTextViewText(R.id.liturgy_widget_progress,snapshot.current?.let { "termina em ${it.minutesRemaining} min · ${it.progressPercent}%" }?:focus?.let { "começa em ${(it.startMinute!!-(now.get(Calendar.HOUR_OF_DAY)*60+now.get(Calendar.MINUTE))).coerceAtLeast(0)} min" }?:""); v.setTextColor(R.id.liturgy_widget_next,Color.parseColor(if(snapshot.current!=null) "#F8C800" else "#78D6D2")); v.setViewVisibility(R.id.liturgy_widget_next,View.VISIBLE) }
        c.packageManager.getLaunchIntentForPackage(c.packageName)?.let { v.setOnClickPendingIntent(R.id.liturgy_widget_root,PendingIntent.getActivity(c,0,it,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)) }; m.updateAppWidget(id,v)
    }
    private fun parse(raw:String):List<LiturgyTimeline.Item> = try { JSONArray(raw).let { a->List(a.length()){n->a.getJSONObject(n).let{ LiturgyTimeline.Item(it.optString("name","Item"),it.optString("startTime").ifBlank{null},it.optString("endTime").ifBlank{null})}}}} catch(_:Exception){emptyList()}
}
