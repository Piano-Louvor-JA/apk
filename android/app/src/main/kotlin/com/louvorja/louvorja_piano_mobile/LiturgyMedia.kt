package com.louvorja.louvorja_piano_mobile

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import java.io.ByteArrayOutputStream
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import android.media.MediaMetadataRetriever
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/** Composição MP4 sem recodificar as faixas baixadas. */
object LiturgyMedia {
    fun register(messenger: BinaryMessenger, context: Context) {
        val worker = Executors.newSingleThreadExecutor()
        val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, "app.louvorja/liturgy-media").setMethodCallHandler { call, result ->
            if (call.method == "mediaDuration") {
                val path = call.argument<String>("path")
                if (path == null) { result.success(0); return@setMethodCallHandler }
                worker.execute {
                    val metadata = MediaMetadataRetriever()
                    try { metadata.setDataSource(path); val duration = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L; main.post { result.success(duration) } }
                    catch (error: Exception) { main.post { result.success(0) } }
                    finally { metadata.release() }
                }
                return@setMethodCallHandler
            }
            if (call.method == "webSnapshot") {
                try {
                    val pages = mutableListOf<WebView>()
                    fun collect(view: View) { if (view is WebView && view.isShown) pages.add(view); if (view is ViewGroup) for (i in view.childCount - 1 downTo 0) collect(view.getChildAt(i)) }
                    collect((context as Activity).window.decorView)
                    val page = pages.maxByOrNull { val rect = Rect(); if (it.getGlobalVisibleRect(rect)) rect.width().toLong() * rect.height() else 0L } ?: throw IllegalStateException()
                    require(page.width > 0 && page.height > 0)
                    val scale = minOf(1f, 1280f / page.width, 2000f / page.height)
                    val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()), maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                    try {
                        val canvas = Canvas(bitmap); canvas.scale(scale, scale); page.draw(canvas)
                        val bytes = ByteArrayOutputStream().use { stream -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream); stream.toByteArray() }
                        result.success(bytes)
                    } finally { bitmap.recycle() }
                } catch (error: Exception) { result.error("WEB_SNAPSHOT", "Página web indisponível", null) }
                return@setMethodCallHandler
            }
            if (call.method == "openPlayer") {
                try {
                    val path = call.argument<String>("path") ?: throw IllegalArgumentException()
                    val player = call.argument<String>("playerId") ?: "associated"
                    val packageId = when (player) { "associated" -> null; "vlc" -> "org.videolan.vlc"; "mpv" -> "is.xyz.mpv"; else -> throw IllegalArgumentException() }
                    val uri = if (path.startsWith("https://") || path.startsWith("http://")) Uri.parse(path) else {
                        val source = File(path); require(source.isFile)
                        val cached = File(context.cacheDir, "liturgy-external-${source.name}")
                        if (source.absolutePath != cached.absolutePath) source.copyTo(cached, overwrite = true)
                        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", cached)
                    }
                    val ext = path.substringBefore('?').substringAfterLast('.').lowercase()
                    val mime = when(ext) { "mp3", "wav", "m4a", "ogg", "aac", "flac" -> "audio/*"; else -> "video/*" }
                    val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    if (packageId != null) intent.setPackage(packageId)
                    context.startActivity(intent); result.success(true)
                } catch (error: Exception) { result.error("PLAYER_MISSING", "Player indisponível neste dispositivo", null) }
                return@setMethodCallHandler
            }
            if (call.method != "mux") { result.notImplemented(); return@setMethodCallHandler }
            val video = call.argument<String>("video")
            val audio = call.argument<String>("audio")
            val output = call.argument<String>("output")
            if (video == null || audio == null || output == null) {
                result.error("NO_PATH", "Faixa não informada", null); return@setMethodCallHandler
            }
            worker.execute {
                val extractors = mutableListOf<MediaExtractor>()
                var muxer: MediaMuxer? = null
                try {
                    val destination = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                    muxer = destination
                    val tracks = listOf(video to "video/", audio to "audio/").map { (path, prefix) ->
                        val extractor = MediaExtractor(); extractors.add(extractor); extractor.setDataSource(path)
                        val index = (0 until extractor.trackCount).first { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true }
                        val format = extractor.getTrackFormat(index); extractor.selectTrack(index)
                        Triple(extractor, destination.addTrack(format), if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) else 1024 * 1024)
                    }
                    destination.start()
                    for ((extractor, index, size) in tracks) {
                        val buffer = ByteBuffer.allocate(maxOf(size, 1024 * 1024))
                        val info = MediaCodec.BufferInfo()
                        while (true) {
                            buffer.clear(); val count = extractor.readSampleData(buffer, 0); if (count < 0) break
                            info.set(0, count, extractor.sampleTime, if ((extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                            destination.writeSampleData(index, buffer, info); extractor.advance()
                        }
                    }
                    destination.stop()
                    main.post { result.success(true) }
                } catch (error: Exception) {
                    main.post { result.error("MUX_ERROR", "Não foi possível compor o vídeo", null) }
                } finally {
                    extractors.forEach { it.release() }; muxer?.release()
                }
            }
        }
    }
}
