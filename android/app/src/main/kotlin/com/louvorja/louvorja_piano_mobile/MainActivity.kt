package com.louvorja.louvorja_piano_mobile

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.provider.Settings
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "app.louvorja/updater"
    private val mediaChannelName = "app.louvorja/media"
    private var pipEventChannel: MethodChannel? = null
    private var multicastLock: android.net.wifi.WifiManager.MulticastLock? = null
    @Volatile private var pipEnabled = false
    private var mediaEventSink: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SPEC 13 (apk#132): receiver de MANIFEST pras ações de mídia —
        // broadcasts do shell do PiP não chegam em receivers dinâmicos
        // NOT_EXPORTED no Android 14+ (log: zero entregas).
        MainActivity.dartPoke = { method ->
            mainHandler().post {
                try {
                    MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        channelName
                    ).invokeMethod(method, null)
                } catch (e: Exception) {
                    android.util.Log.e("LouvorPip", "pokeDart($method) falhou", e)
                }
            }
        }
        // Player real emite estado pelo Dart. Atualiza as ações do PiP com
        // esse estado (RemoteAction é snapshot; sem isto fica PLAY mesmo
        // tocando — A15, 15:57). A notificação é atualizada pela sessão.
        MainActivity.refreshPipActions = {
            mainHandler().post {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && isInPictureInPictureMode) {
                    setPictureInPictureParams(pipParamsBuilder().build())
                }
            }
        }

        // Canal principal (installer, multicast, foreground, pip)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPipEventListener" -> {
                        // Flutter registra o canal que recebe onPipChanged(active: bool)
                        pipEventChannel = MethodChannel(
                            flutterEngine.dartExecutor.binaryMessenger,
                            "app.louvorja/pip"
                        )
                        android.util.Log.d("LouvorPip", "setPipEventListener registrado")
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("NO_PATH", "caminho ausente", null)
                        } else {
                            Thread { installApk(File(path), result) }.start()
                        }
                    }
                    "acquireMulticastLock" -> {
                        val wifi = applicationContext.getSystemService(
                            android.content.Context.WIFI_SERVICE
                        ) as android.net.wifi.WifiManager
                        multicastLock = wifi.createMulticastLock("louvorja-ssdp")
                            .apply { setReferenceCounted(false); acquire() }
                        result.success(true)
                    }
                    "startPalcoForeground" -> {
                        try {
                            PalcoForegroundService.start(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FG_FAIL", e.message, null)
                        }
                    }
                    "stopPalcoForeground" -> {
                        PalcoForegroundService.stop(applicationContext)
                        result.success(true)
                    }
                    "releaseMulticastLock" -> {
                        multicastLock?.let { if (it.isHeld) it.release() }
                        multicastLock = null
                        result.success(true)
                    }
                    "setPipEnabled" -> {
                        pipEnabled = call.argument<Boolean>("enabled") == true
                        android.util.Log.d("LouvorPip", "setPipEnabled=$pipEnabled")
                        // Auto-enter (API 31+): atualiza os params imediatamente
                        // pra evitar corrida com onStop (o sistema lê os params
                        // quando a Activity vai pra background).
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                // Sessão tem que existir ANTES: os botões da
                                // barra do PiP vêm da MediaSession (token).
                                MediaSessionController.ensureInit(applicationContext)
                                setPictureInPictureParams(pipParamsBuilder().build())
                            } catch (e: Exception) {
                                android.util.Log.e("LouvorPip", "setPictureInPictureParams falhou", e)
                            }
                        }
                        result.success(true)
                    }
                    "updateLiturgyWidget" -> {
                        val i1 = Intent(LiturgyWidgetProvider.WIDGET_TITLE)
                        i1.setPackage(packageName)
                        sendBroadcast(i1)
                        val i2 = Intent(LiturgyWidgetLargeProvider.ACTION_UPDATE)
                        i2.setPackage(packageName)
                        sendBroadcast(i2)
                        result.success(true)
                    }
                    // mediaPlay/mediaPause/mediaPrev/mediaNext: o DART cuida
                    // (PipController registra handler global que opera no
                    // player da faixa em execução — mesmo do overlay).
                    "mediaPlay", "mediaPause", "mediaPrev", "mediaNext" -> result.success(true)
                    else -> result.notImplemented()
                }
            }

        // Canal de mídia (MediaSession, notificação, lock screen)
        val mc = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
        mediaEventSink = mc
        mc.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    MediaSessionController.init(applicationContext)
                    MediaSessionController.onPlayPause = { play ->
                        android.util.Log.d("LouvorPip", "kotlin->dart onPlayPause play=$play")
                        mainHandler().post {
                            try {
                                mc.invokeMethod("onPlayPause", play)
                                android.util.Log.d("LouvorPip", "kotlin->dart onPlayPause OK")
                            } catch (e: Exception) {
                                android.util.Log.e("LouvorPip", "kotlin->dart falhou", e)
                            }
                        }
                    }
                    MediaSessionController.onPrev = {
                        mainHandler().post { mc.invokeMethod("onPrev", null) }
                    }
                    MediaSessionController.onNext = {
                        mainHandler().post { mc.invokeMethod("onNext", null) }
                    }
                    result.success(null)
                }
                "setMetadata" -> {
                    MediaSessionController.setMetadata(
                        title = call.argument<String>("title") ?: "",
                        album = call.argument<String>("album") ?: "",
                        artUrl = call.argument<String>("artUrl"),
                        durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0,
                    )
                    result.success(null)
                }
                "setPlaybackState" -> {
                    MediaSessionController.setPlaybackState(
                        playing = call.argument<Boolean>("isPlaying") == true,
                        positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0,
                    )
                    result.success(null)
                }
                "show" -> {
                    MediaSessionController.show()
                    result.success(null)
                }
                "startMediaService" -> {
                    // FGS de mídia: processo vivo em background (One UI
                    // congela sem isso — FreecessController "BG freezed").
                    try {
                        MediaPlaybackService.start(applicationContext)
                    } catch (e: Exception) {
                        android.util.Log.e("LouvorPip", "startMediaService falhou", e)
                    }
                    result.success(null)
                }
                "stopMediaService" -> {
                    try {
                        MediaPlaybackService.stop(applicationContext)
                    } catch (e: Exception) {
                        android.util.Log.e("LouvorPip", "stopMediaService falhou", e)
                    }
                    result.success(null)
                }
                "hide" -> {
                    MediaSessionController.hide()
                    result.success(null)
                }
                "release" -> {
                    MediaSessionController.release(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// PiP: entra ao sair do app enquanto NowPlaying ativo.
    ///
    /// Android 12+ (API 31+): usa setAutoEnterEnabled — o sistema entra em PiP
    /// sozinho no home/switch, sem depender do onUserLeaveHint deprecated
    /// (que corridava com o setPipEnabled async do Flutter — bug apk#132 no
    /// Android 16 do A15). onUserLeaveHint fica só pro fallback < API 31.
    @Suppress("DEPRECATION")
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return // auto-enter cuida
        if (!pipEnabled || Build.VERSION.SDK_INT < Build.VERSION_CODES.O || isInPictureInPictureMode) return
        enterPictureInPictureMode(legacyPipParams())
    }

    private fun pipParamsBuilder(): PictureInPictureParams.Builder {
        val b = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            b.setAutoEnterEnabled(pipEnabled)
            b.setActions(MediaSessionController.remoteActions())
            // NOTA apk#132: setMediaSessionToken não existe na API pública
            // (é interna do sistema). Os botões da barra do PiP disparam as
            // RemoteActions → MediaActionReceiver (manifest) → pokeDart.
        }
        return b
    }

    private fun legacyPipParams(): PictureInPictureParams = pipParamsBuilder().build()

    /// O sistema lê os params do PiP no onStop — precisa atualizar quando o
    /// Flutter liga/desliga (entrada/saída da NowPlaying).
    override fun onStop() {
        super.onStop()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && pipEnabled && !isInPictureInPictureMode) {
            setPictureInPictureParams(pipParamsBuilder().build())
        }
    }

    companion object {
        /// Ponte estática pra mandar eventos de mídia ao Dart quando os
        /// callbacks da página não estão setados (PiP sem página viva).
        @Volatile
        var dartPoke: ((String) -> Unit)? = null

        @Volatile
        var refreshPipActions: (() -> Unit)? = null

        fun pokeDart(method: String) {
            dartPoke?.invoke(method)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPip: Boolean,
        newConfig: android.content.res.Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPip, newConfig)
        android.util.Log.d("LouvorPip", "onPictureInPictureModeChanged isInPip=$isInPip hasChannel=${pipEventChannel != null}")
        mainHandler().post {
            try {
                pipEventChannel?.invokeMethod("onPipChanged", isInPip)
            } catch (e: Exception) {
                android.util.Log.e("LouvorPip", "invokeMethod onPipChanged falhou", e)
            }
        }
    }

    private fun installApk(file: File, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    android.net.Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            mainHandler().post { result.success("needs_permission") }
            return
        }
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        try {
            file.inputStream().use { input ->
                session.openWrite("apk", 0, file.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
        } catch (e: Exception) {
            session.abandon()
            mainHandler().post { result.error("WRITE_FAIL", e.message, null) }
            return
        }
        val intent = Intent(this, InstallResultReceiver::class.java)
        intent.action = "app.louvorja.INSTALL_RESULT"
        val pi = PendingIntent.getBroadcast(
            this, sessionId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        session.commit(pi.intentSender)
        session.close()
        mainHandler().post { result.success("delivered") }
    }

    private fun mainHandler() = android.os.Handler(android.os.Looper.getMainLooper())

    override fun onDestroy() {
        super.onDestroy()
        MediaSessionController.release(applicationContext)
    }
}

class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE
        )
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val dialog = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (dialog != null) {
                    dialog.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(dialog)
                }
            }
            PackageInstaller.STATUS_SUCCESS ->
                android.util.Log.i("LouvorJaUpdater", "install OK")
            else ->
                android.util.Log.w(
                    "LouvorJaUpdater",
                    "install falhou: " +
                        intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                )
        }
    }
}
