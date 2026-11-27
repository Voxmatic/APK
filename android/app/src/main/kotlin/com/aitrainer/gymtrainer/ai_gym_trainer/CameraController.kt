package com.aitrainer.gymtrainer.ai_gym_trainer

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.doOnAttach
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/// Owns CameraX lifecycle. Frames are analysed in a dedicated single-thread
/// executor with STRATEGY_KEEP_ONLY_LATEST so no frame is ever queued twice.
/// Failures are returned to the caller instead of being silently swallowed.
class CameraController(
    private val activity: FlutterActivity,
    private val onFrame: (Bitmap, Int) -> Unit,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var provider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var analysis: ImageAnalysis? = null
    private var previewView: PreviewView? = null

    @Volatile
    private var running = false

    var lastError: String = ""

    fun permissionGranted(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    /// Bind a freshly created platform view. Starting is deferred until the
    /// view is actually attached, which removes the original crash path.
    fun bind(view: PreviewView) {
        previewView = view
        view.doOnAttach {
            if (previewView === view && !running) startInternal()
        }
    }

    fun isBoundTo(view: PreviewView): Boolean = previewView === view

    fun initialize(): Map<String, Any?> = try {
        provider = ProcessCameraProvider.getInstance(activity).get()
        lastError = ""
        mapOf("ok" to true, "cameraId" to "front")
    } catch (e: Exception) {
        lastError = "Camera initialization failed: ${e.message}"
        mapOf("ok" to false, "code" to "CAMERA_INIT_FAILED", "message" to lastError)
    }

    fun start(): Map<String, Any?> {
        if (!permissionGranted()) {
            lastError = "Camera permission not granted"
            return mapOf("ok" to false, "code" to "PERMISSION_DENIED", "message" to lastError)
        }
        val view = previewView
        if (view == null) {
            lastError = "Preview view is not registered"
            return mapOf("ok" to false, "code" to "INVALID_STATE", "message" to lastError)
        }
        if (!view.isAttachedToWindow) {
            // Not an error: the view will call startInternal on attach.
            return mapOf("ok" to true, "pending" to true)
        }
        return startInternal()
    }

    private fun startInternal(): Map<String, Any?> {
        if (running) return mapOf("ok" to true)
        val p = provider ?: run {
            val result = initialize()
            if (result["ok"] != true) return result
            provider ?: return mapOf("ok" to false, "code" to "CAMERA_INIT_FAILED")
        }
        val view = previewView ?: return mapOf(
            "ok" to false,
            "code" to "INVALID_STATE",
            "message" to "Preview view is not registered",
        )
        return try {
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(view.surfaceProvider)
            }
            val rotation = displayRotation()
            analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setTargetRotation(rotation)
                .build()
                .also { it.setAnalyzer(executor) { proxy -> analyze(proxy) } }
            p.unbindAll()
            camera = p.bindToLifecycle(
                activity,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                preview,
                analysis!!,
            )
            running = true
            lastError = ""
            mapOf("ok" to true, "cameraId" to "front")
        } catch (e: Exception) {
            running = false
            lastError = "Camera start failed: ${e.message}"
            mapOf("ok" to false, "code" to "CAMERA_START_FAILED", "message" to lastError)
        }
    }

    /// Activity display is always attached; PreviewView.display may not be.
    private fun displayRotation(): Int =
        activity.window?.decorView?.display?.rotation
            ?: activity.resources.configuration.orientation.let { orientation ->
                when (orientation) {
                    android.content.res.Configuration.ORIENTATION_LANDSCAPE -> 90
                    android.content.res.Configuration.ORIENTATION_PORTRAIT -> 0
                    else -> 0
                }
            }

    fun stop(): Map<String, Any?> {
        running = false
        analysis?.clearAnalyzer()
        analysis = null
        provider?.unbindAll()
        camera = null
        return mapOf("ok" to true)
    }

    fun close() {
        stop()
        executor.shutdownNow()
        previewView = null
    }

    fun isRunning(): Boolean = running

    fun status(): Map<String, Any?> = mapOf(
        "running" to running,
        "permission" to permissionGranted(),
        "fps" to 30.0,
        "cameraId" to "front",
        "error" to lastError,
    )

    private fun analyze(proxy: ImageProxy) {
        if (!running) {
            proxy.close()
            return
        }
        try {
            val bitmap = rgbaToBitmap(proxy)
            onFrame(bitmap, proxy.imageInfo.rotationDegrees)
        } catch (e: Exception) {
            lastError = "Frame conversion failed: ${e.message}"
        } finally {
            proxy.close()
        }
    }

    /// Converts CameraX RGBA_8888 output into an ARGB Bitmap. Pixel and row
    /// strides are respected; a malformed buffer produces a typed error above.
    private fun rgbaToBitmap(image: ImageProxy): Bitmap {
        val width = image.width
        val height = image.height
        val plane = image.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        require(pixelStride >= 3) { "Unsupported pixel stride $pixelStride" }
        val pixels = IntArray(width * height)
        for (y in 0 until height) {
            val rowStart = y * rowStride
            for (x in 0 until width) {
                val offset = rowStart + x * pixelStride
                val r = buffer.get(offset).toInt() and 0xFF
                val g = buffer.get(offset + 1).toInt() and 0xFF
                val b = buffer.get(offset + 2).toInt() and 0xFF
                pixels[y * width + x] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
    }
}
