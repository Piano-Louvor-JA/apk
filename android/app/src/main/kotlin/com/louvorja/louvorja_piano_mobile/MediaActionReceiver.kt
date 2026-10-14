package com.louvorja.louvorja_piano_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Receiver ESTÁTICO (AndroidManifest) pras ações de mídia.
///
/// SPEC 13 (apk#132): os RemoteActions do PiP disparam PendingIntents a
/// partir do SHELL do sistema (com.android.wm.shell). No Android 14+,
/// receivers registrados DINAMICAMENTE com RECEIVER_NOT_EXPORTED não
/// recebem esses broadcasts (o log mostrou zero entregas —
/// "receiver action=" nunca disparava). Receiver de manifesto é entregue
/// sempre, com o app vivo ou não (padrão YouTube/Spotify).
class MediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("LouvorPip", "static receiver action=${intent.action}")
        MediaSessionController.dispatchAction(intent.action)
    }
}
