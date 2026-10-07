package com.louvorja.louvorja_piano_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.os.Build
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import java.net.URL
import java.util.concurrent.Executors

object MediaSessionController {

    private const val CHANNEL_ID = "louvorja_playback"
    private const val NOTIF_ID = 20260820
    private const val ACT_PLAY = "app.louvorja.MEDIA_PLAY"
    private const val ACT_PAUSE = "app.louvorja.MEDIA_PAUSE"
    private const val ACT_PREV = "app.louvorja.MEDIA_PREV"
    private const val ACT_NEXT = "app.louvorja.MEDIA_NEXT"

    private var session: MediaSessionCompat? = null
    private var nMgr: NotificationManager? = null
    private var ctx: Context? = null
    private var isPlaying = false
    private var posMs = 0L
    private var lastPipSentPlaying: Boolean? = null
    private var durMs = 0L
    private var trackTitle = ""
    private var trackAlbum = ""
    private var artBitmap: android.graphics.Bitmap? = null
    private val ex = Executors.newSingleThreadExecutor()

    /// Callbacks que Dart registra uma vez.
    var onPlayPause: ((Boolean) -> Unit)? = null
    var onPrev: (() -> Unit)? = null
    var onNext: (() -> Unit)? = null

    fun init(context: Context) {
        if (session != null) return // já iniciada (idempotente)
        ctx = context
        nMgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel(context)
        session = MediaSessionCompat(context, "LouvorJa").apply {
            isActive = true
            // SPEC 13 (apk#132): PlaybackState INICIAL obrigatório — sem ele
            // `dumpsys media_session` mostra state=null e o sistema NÃO roteia
            // os botões do PiP/lock pra sessão (o PiP do One UI ignora
            // RemoteActions e sessões sem estado).
            setPlaybackState(
                PlaybackStateCompat.Builder()
                    .setActions(
                        PlaybackStateCompat.ACTION_PLAY or
                            PlaybackStateCompat.ACTION_PAUSE or
                            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                            PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                            PlaybackStateCompat.ACTION_SEEK_TO
                    )
                    .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 1f)
                    .build()
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    android.util.Log.d("LouvorPip", "session onPlay")
                    // Callbacks da página podem não estar setados (PiP sem
                    // página viva): cai no pokeDart, que roteia pro player
                    // global via Dart.
                    if (onPlayPause != null) onPlayPause?.invoke(true)
                    else MainActivity.pokeDart("mediaPlay")
                }
                override fun onPause() {
                    android.util.Log.d("LouvorPip", "session onPause")
                    if (onPlayPause != null) onPlayPause?.invoke(false)
                    else MainActivity.pokeDart("mediaPause")
                }
                override fun onSkipToPrevious() {
                    android.util.Log.d("LouvorPip", "session onSkipToPrevious")
                    if (onPrev != null) onPrev?.invoke()
                    else MainActivity.pokeDart("mediaPrev")
                }
                override fun onSkipToNext() {
                    android.util.Log.d("LouvorPip", "session onSkipToNext")
                    if (onNext != null) onNext?.invoke()
                    else MainActivity.pokeDart("mediaNext")
                }
            })
        }
        val filter = IntentFilter().apply {
            addAction(ACT_PLAY); addAction(ACT_PAUSE)
            addAction(ACT_PREV); addAction(ACT_NEXT)
        }
        // SPEC 13 (apk#132): receiver DINÂMICO com RECEIVER_EXPORTED.
        //
        // Provas no dumpsys (12:44/13:22):
        //  - NOT_EXPORTED: broadcast "skipped by policy" (One UI não entrega
        //    cross-app pra receiver não exportado);
        //  - receiver de MANIFEST: mesmo bloqueio ("Background execution not
        //    allowed" com app em PiP/background).
        // Receiver dinâmico EXPORTED é entregue com o processo vivo — e em
        // PiP o processo está vivo. As actions são namespaced; spoofing de
        // outro app no máximo pausa/retoma o player (sem dado sensível).
        if (Build.VERSION.SDK_INT >= 33)
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        else
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
    }

    fun setMetadata(title: String, album: String, artUrl: String?, durationMs: Long) {
        trackTitle = title; trackAlbum = album; durMs = durationMs
        artBitmap = null
        val meta = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
            .build()
        session?.setMetadata(meta)
        // Capa em background
        if (!artUrl.isNullOrBlank()) {
            val url = artUrl
            ex.execute {
                try {
                    val bmp = BitmapFactory.decodeStream(URL(url).openStream())
                    if (bmp != null) {
                        artBitmap = bmp
                        session?.setMetadata(MediaMetadataCompat.Builder()
                            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, trackTitle)
                            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, trackAlbum)
                            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durMs)
                            .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bmp)
                            .build())
                    }
                } catch (_: Exception) {}
            }
        }
        postNotification()
    }

    fun setPlaybackState(playing: Boolean, positionMs: Long) {
        isPlaying = playing; posMs = positionMs
        val state = if (playing) PlaybackStateCompat.STATE_PLAYING
                     else PlaybackStateCompat.STATE_PAUSED
        val actions = PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
            PlaybackStateCompat.ACTION_SEEK_TO
        session?.setPlaybackState(PlaybackStateCompat.Builder()
            .setActions(actions).setState(state, positionMs, 1f).build())
        postNotification()
        // PiP RemoteActions são uma fotografia dos parâmetros. Reenvia ao
        // sistema SÓ na transição PLAY↔PAUSE (posição/segundo não muda os
        // ícones — reenviar a cada tick custa IPC e o One UI derruba).
        if (playing != lastPipSentPlaying) {
            lastPipSentPlaying = playing
            MainActivity.refreshPipActions?.invoke()
        }
    }

    fun show() = postNotification()

    fun hide() { nMgr?.cancel(NOTIF_ID) }

    fun release(c: Context) {
        nMgr?.cancel(NOTIF_ID)
        session?.isActive = false; session?.release(); session = null
        try { c.unregisterReceiver(receiver) } catch (_: Exception) {}
        ex.shutdown()
    }

    /// Ações para PiP (Android 12+).
    fun remoteActions(): java.util.ArrayList<android.app.RemoteAction> {
        val c = ctx ?: return java.util.ArrayList()
        val list = java.util.ArrayList<android.app.RemoteAction>()
        list.add(android.app.RemoteAction(
            android.graphics.drawable.Icon.createWithResource(c, android.R.drawable.ic_media_previous),
            "Anterior", "Verso anterior",
            PendingIntent.getBroadcast(c, 1, Intent(ACT_PREV), PendingIntent.FLAG_IMMUTABLE)))
        val (playIcon, playAct, playLabel) = if (isPlaying)
            Triple(android.R.drawable.ic_media_pause, ACT_PAUSE, "Pausar")
        else
            Triple(android.R.drawable.ic_media_play, ACT_PLAY, "Play")
        list.add(android.app.RemoteAction(
            android.graphics.drawable.Icon.createWithResource(c, playIcon),
            playLabel, playLabel,
            PendingIntent.getBroadcast(c, 2, Intent(playAct), PendingIntent.FLAG_IMMUTABLE)))
        list.add(android.app.RemoteAction(
            android.graphics.drawable.Icon.createWithResource(c, android.R.drawable.ic_media_next),
            "Próximo", "Próximo verso",
            PendingIntent.getBroadcast(c, 3, Intent(ACT_NEXT), PendingIntent.FLAG_IMMUTABLE)))
        return list
    }

    // -- interno --

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            android.util.Log.d("LouvorPip", "receiver action=${i.action}")
            when (i.action) {
                ACT_PLAY -> dispatchAction(i.action)
                ACT_PAUSE -> dispatchAction(i.action)
                ACT_PREV -> dispatchAction(i.action)
                ACT_NEXT -> dispatchAction(i.action)
            }
        }
    }

    /// Init idempotente (chamado antes de setar os params do PiP).
    fun ensureInit(context: Context) = init(context)

    /// Token da sessão pro PiP usar os botões da MediaSession (API 31+).
    /// MediaSessionCompat.Token.getToken() retorna Object (framework Token).
    fun sessionToken(): android.media.session.MediaSession.Token? {
        val s = session ?: return null
        @Suppress("UNCHECKED_CAST", "CAST_NEVER_SUCCEEDS")
        return s.sessionToken.getToken() as? android.media.session.MediaSession.Token
    }

    /// Dispatch único usado pelo MediaActionReceiver (manifest) — os
    /// callbacks podem não estar setados (página fechada): o handler padrão
    /// do Flutter Engine roteia pro player global.
    fun dispatchAction(action: String?) {
        android.util.Log.d("LouvorPip", "dispatchAction=$action hasPlayCb=${onPlayPause != null}")
        when (action) {
            ACT_PLAY -> {
                if (onPlayPause != null) onPlayPause?.invoke(true)
                else MainActivity.pokeDart("mediaPlay")
            }
            ACT_PAUSE -> {
                if (onPlayPause != null) onPlayPause?.invoke(false)
                else MainActivity.pokeDart("mediaPause")
            }
            ACT_PREV -> if (onPrev != null) onPrev?.invoke() else MainActivity.pokeDart("mediaPrev")
            ACT_NEXT -> if (onNext != null) onNext?.invoke() else MainActivity.pokeDart("mediaNext")
        }
    }

    private fun postNotification() {
        val c = ctx ?: return
        val s = session ?: return
        val launch = c.packageManager.getLaunchIntentForPackage(c.packageName)
        val ci = launch?.let {
            PendingIntent.getActivity(c, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val style = MediaStyle().setMediaSession(s.sessionToken)
            .setShowActionsInCompactView(0, 1, 2)
        val n = NotificationCompat.Builder(c, CHANNEL_ID)
            .setContentTitle(trackTitle)
            .setContentText(trackAlbum)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(ci)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(style)
            .addAction(android.R.drawable.ic_media_previous, "Anterior",
                PendingIntent.getBroadcast(c, 1, Intent(ACT_PREV), PendingIntent.FLAG_IMMUTABLE))
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pausar" else "Play",
                PendingIntent.getBroadcast(c, 2,
                    Intent(if (isPlaying) ACT_PAUSE else ACT_PLAY),
                    PendingIntent.FLAG_IMMUTABLE))
            .addAction(android.R.drawable.ic_media_next, "Próximo",
                PendingIntent.getBroadcast(c, 3, Intent(ACT_NEXT), PendingIntent.FLAG_IMMUTABLE))
            .build()
        nMgr?.notify(NOTIF_ID, n)
    }

    private fun createChannel(c: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Player", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Controles do player"; setShowBadge(false) }
            nMgr?.createNotificationChannel(ch)
        }
    }
}
