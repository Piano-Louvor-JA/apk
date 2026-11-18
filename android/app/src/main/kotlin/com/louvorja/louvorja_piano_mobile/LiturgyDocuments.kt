package com.louvorja.louvorja_piano_mobile

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.min
import kotlin.math.max

/** PDF local renderizado sob demanda, fora da thread da interface. */
object LiturgyDocuments {
    fun register(messenger: BinaryMessenger) {
        val worker = Executors.newSingleThreadExecutor()
        val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, "app.louvorja/liturgy-documents").setMethodCallHandler { call, result ->
            if (call.method != "pdfInfo" && call.method != "pdfPage") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("NO_PATH", "Arquivo não informado", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val output: Any = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                        PdfRenderer(descriptor).use { renderer ->
                            if (call.method == "pdfInfo") renderer.pageCount
                            else {
                                val index = call.argument<Int>("page") ?: 0
                                renderer.openPage(index).use { page ->
                                    val targetWidth = (call.argument<Int>("width") ?: 1600).coerceIn(320, 2400)
                                    val scale = min(targetWidth.toFloat() / max(1, page.width), 4000f / max(1, page.height))
                                    val bitmap = Bitmap.createBitmap(max(1, (page.width * scale).toInt()), max(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                                    try {
                                        bitmap.eraseColor(Color.WHITE)
                                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                        ByteArrayOutputStream().use { stream -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream); stream.toByteArray() }
                                    } finally { bitmap.recycle() }
                                }
                            }
                        }
                    }
                    main.post { result.success(output) }
                } catch (error: Exception) {
                    main.post { result.error("PDF_ERROR", "Não foi possível abrir esta página", null) }
                }
            }
        }
    }
}
