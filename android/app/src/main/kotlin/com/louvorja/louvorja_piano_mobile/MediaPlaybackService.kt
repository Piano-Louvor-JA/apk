package com.louvorja.louvorja_piano_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.support.v4.media.session.MediaSessionCompat

/// Foreground service DE MÍDIA (apk#132 follow-up, solução definitiva no
/// radar): mantém o processo VIVO enquanto um hino toca, fora do Palco.
///
/// Evidência One UI/Android 16 (logcat A15 22:26-22:28): "FreecessController:
/// BG freezed" — com o app em background SEM serviço foreground de mídia, a
/// Samsung congela o processo; o Dart para e nenhum controle (notificação,
/// PiP, lock screen) executa, mesmo com MediaSession/broadcasts corretos.
///
/// O MediaSessionController continua sendo o dono da MediaSession e da
/// notificação MediaStyle — este serviço só segura o processo vivo. Nota:
/// a notificação FGS é distinta da notificação MediaStyle da sessão.
class MediaPlaybackService : Service() {

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Player LouvorJA",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantém o hino tocando em segundo plano"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = launch?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Piano LouvorJA")
            .setContentText("Hino em reprodução")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "louvorja_media_playback"
        const val NOTIF_ID = 20261006

        /// Idempotente: sobe o FGS de mídia (chamar quando o player toca).
        fun start(context: Context) {
            val i = Intent(context, MediaPlaybackService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MediaPlaybackService::class.java))
        }
    }
}
