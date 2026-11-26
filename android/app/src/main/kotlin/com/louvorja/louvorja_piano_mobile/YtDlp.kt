package com.louvorja.louvorja_piano_mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Download de vídeos online pelo yt-dlp (o mesmo motor do desktop), com o
 * Python e o QuickJS que vêm no youtubedl-android. Baixa vídeo (mp4) e
 * áudio (m4a) separados numa só chamada; quem junta é o LiturgyMedia (mux
 * nativo, sem recodificar), então o pacote do ffmpeg não é necessário.
 */
object YtDlp {
    private const val TAG = "LouvorYtDlp"
    private const val CHANNEL = "app.louvorja/ytdlp"
    // O yt-dlp tem ~3 MB; bem menos que isso é arquivo cortado.
    private const val MIN_YTDLP_BYTES = 1_000_000L

    // Uma fila só: downloads e a atualização do yt-dlp nunca rodam juntos
    // (a atualização troca o arquivo do yt-dlp e quebra quem estiver usando).
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    @Volatile private var ready = false
    @Volatile private var updated = false

    fun register(messenger: BinaryMessenger, context: Context) {
        val app = context.applicationContext
        val channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "download" -> {
                    val url = call.argument<String>("url")
                    val dir = call.argument<String>("dir")
                    val id = call.argument<String>("id") ?: "ytdlp"
                    val maxHeight = call.argument<Int>("maxHeight") ?: 720
                    if (url == null || dir == null) {
                        result.error("ARGS", "url/dir ausentes", null)
                    } else {
                        worker.execute { download(app, channel, url, File(dir), id, maxHeight, result) }
                    }
                }
                "cancel" -> {
                    val id = call.argument<String>("id") ?: "ytdlp"
                    result.success(
                        try { YoutubeDL.getInstance().destroyProcessById(id) } catch (e: Exception) { false }
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Roda na fila [worker], antes do download. */
    private fun ensureReady(app: Context) {
        if (!ready) {
            YoutubeDL.getInstance().init(app)
            ready = true
        }
        repairIfBroken(app)
        // Atualiza o yt-dlp uma vez por abertura do app (o YouTube muda
        // sempre; o desktop faz o mesmo). Fica antes do primeiro download,
        // na mesma fila, para não trocar o arquivo no meio de um download.
        if (!updated) {
            updated = true
            try {
                val status = YoutubeDL.getInstance()
                    .updateYoutubeDL(app, YoutubeDL.UpdateChannel.STABLE)
                Log.i(TAG, "atualização do yt-dlp: $status")
            } catch (e: Exception) {
                Log.w(TAG, "não deu para atualizar o yt-dlp", e)
            }
        }
    }

    /**
     * Se o arquivo do yt-dlp ficou vazio ou cortado (atualização interrompida),
     * volta para a cópia que vem no apk e força uma nova atualização. A
     * biblioteca só confere o número da versão salvo, não o arquivo.
     */
    private fun repairIfBroken(app: Context) {
        val dir = File(app.noBackupFilesDir, "youtubedl-android/yt-dlp")
        val bin = File(dir, "yt-dlp")
        if (bin.isFile && bin.length() >= MIN_YTDLP_BYTES) return
        Log.w(TAG, "yt-dlp danificado (${bin.length()} bytes); restaurando")
        bin.delete()
        app.getSharedPreferences("youtubedl-android", Context.MODE_PRIVATE)
            .edit().remove("dlpVersion").remove("dlpVersionName").apply()
        YoutubeDL.getInstance().init_ytdlp(app, dir)
        updated = false
    }

    private fun download(
        app: Context,
        channel: MethodChannel,
        url: String,
        dir: File,
        id: String,
        maxHeight: Int,
        result: MethodChannel.Result,
    ) {
        try {
            ensureReady(app)
            dir.mkdirs()
            dir.listFiles()?.forEach { it.delete() }
            val request = YoutubeDLRequest(url).apply {
                // Vídeo H.264 (toca em qualquer TV) até maxHeight + áudio m4a,
                // separados (vírgula); sem vídeo separado, o arquivo único.
                addOption(
                    "-f",
                    "bv*[ext=mp4][vcodec^=avc1][height<=$maxHeight],ba[ext=m4a]/b[ext=mp4][height<=$maxHeight]/b[ext=mp4]"
                )
                addOption("-o", File(dir, "%(format_id)s.%(ext)s").absolutePath)
                addOption("--no-playlist")
                addOption("--no-mtime")
                addOption("--no-part")
                addOption("--no-cache-dir")
                addOption("--retries", "5")
                addOption("--fragment-retries", "5")
            }
            var stage = 0
            val response = YoutubeDL.getInstance().execute(request, id, false) { progress, _, line ->
                if (line.contains("[download] Destination:")) stage++
                val percent = progress.coerceIn(0f, 100f)
                main.post {
                    channel.invokeMethod(
                        "progress",
                        mapOf("id" to id, "percent" to percent.toDouble(), "stage" to stage)
                    )
                }
            }
            val files = dir.listFiles()?.filter { it.isFile && it.length() > 0 } ?: emptyList()
            val audio = files.firstOrNull { it.extension == "m4a" }
            val video = files.firstOrNull { it.extension == "mp4" }
            main.post {
                when {
                    video == null && audio == null -> {
                        val tail = (response.out + "\n" + response.err).trim().takeLast(800)
                        Log.w(TAG, "nada baixado: $tail")
                        result.error("EMPTY", "nenhum arquivo baixado: $tail", null)
                    }
                    else -> result.success(
                        mapOf("video" to video?.absolutePath, "audio" to audio?.absolutePath)
                    )
                }
            }
        } catch (e: YoutubeDL.CanceledException) {
            main.post { result.error("CANCELED", "cancelado", null) }
        } catch (e: Throwable) {
            // Throwable, não só Exception: um Error (ExceptionInInitializerError,
            // UnsatisfiedLinkError…) solto nesta thread fecha o app inteiro.
            Log.w(TAG, "download falhou", e)
            main.post { result.error("FAILED", e.message ?: e.toString(), null) }
        }
    }
}
