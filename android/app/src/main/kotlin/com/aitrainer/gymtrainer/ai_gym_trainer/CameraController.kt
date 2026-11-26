package com.aitrainer.gymtrainer.ai_gym_trainer

import android.graphics.Bitmap
import android.media.Image
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/// Owns CameraX lifecycle. Frames are analysed in a dedicated single-thread
/// executor with STRATEGY_KEEP_ONLY_LATEST so no frame is ever queued twice.
class CameraController(
    private val activity: FlutterActivity,
    private val previewView: PreviewView,
    private val onFrame: (Bitmap, Int) -> Unit,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var provider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var analysis: ImageAnalysis? = null
    @Volatile
    private var running = false
    @Volatile
    var permissionGranted = false

    fun initialize(): Boolean {
        return try {
            provider = ProcessCameraProvider.getInstance(activity).get()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun start() {
        val p = provider ?: if (!initialize()) return else provider ?: return
        if (running) return
        try {
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }
            analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setTargetRotation(previewView.display.rotation)
                .build()
                .also { it.setAnalyzer(executor) { proxy -> analyze(proxy) } }
            p.unbindAll()
            val imageAnalysis = analysis ?: return
            camera = p.bindToLifecycle(
                activity,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                preview,
                imageAnalysis,
            )
            running = true
        } catch (_: Exception) {
            running = false
        }
    }

    fun stop() {
        running = false
        analysis?.clearAnalyzer()
        provider?.unbindAll()
        camera = null
    }

    fun close() {
        stop()
        executor.shutdownNow()
    }

    fun isRunning(): Boolean = running

    private fun analyze(proxy: ImageProxy) {
        if (!running) {
            proxy.close()
            return
        }
        try {
            val bitmap = rgbaToBitmap(proxy)
            onFrame(bitmap, proxy.imageInfo.rotationDegrees)
        } catch (_: Exception) {
            // A malformed frame must never take down the analyzer thread.
        } finally {
            proxy.close()
        }
    }

    /// Converts CameraX RGBA_8888 output into an ARGB Bitmap.
    private fun rgbaToBitmap(image: ImageProxy): Bitmap {
        val width = image.width
        val height = image.height
        val plane = image.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val pixels = IntArray(width * height)
        for (y in 0 until height) {
            buffer.position(y * rowStride)
            var x = 0
            while (x < width) {
                val r = buffer.get().toInt() and 0xFF
                val g = buffer.get().toInt() and 0xFF
                val b = buffer.get().toInt() and 0xFF
                if (pixelStride == 4 && buffer.remaining() > 0) buffer.get()
                pixels[y * width + x] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
                x++
            }
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bitmap
    }
}
