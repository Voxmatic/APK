package com.aitrainer.gymtrainer.ai_gym_trainer

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.atomic.AtomicLong

/// Wraps MediaPipe Pose Landmarker in LIVE_STREAM mode. The native analyzer
/// feeds frames here; compact landmark maps are emitted to Dart via EventChannel.
/// Raw frames never leave native code and are never recycled while MediaPipe
/// may still hold a reference to them.
class PoseProcessor(
    private val context: Context,
    private val onFrame: (Map<String, Any?>) -> Unit,
    private val onError: (String) -> Unit,
) {
    private var landmarker: PoseLandmarker? = null
    private var lastTimestampMs = 0L
    private var started = false
    private var modelReady = false
    private var lastError = ""

    @Volatile
    var lastInferenceMs: Double = 0.0
        private set

    @Volatile
    private var inferenceCount: Int = 0

    val running: Boolean
        get() = started && landmarker != null

    fun initialize(): Boolean {
        if (landmarker != null) return true
        return try {
            val assetName = "flutter_assets/assets/models/pose/pose_landmarker_lite.task"
            val bytes = context.assets.open(assetName).use { it.readBytes() }
            val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
            val sha = digest.joinToString("") { "%02x".format(Locale.ROOT, it) }
            if (sha != EXPECTED_SHA256) {
                lastError = "Pose model checksum mismatch: $sha"
                onError(lastError)
                return false
            }
            val buffer = ByteBuffer.allocateDirect(bytes.size)
            buffer.put(bytes)
            buffer.rewind()
            val baseOptions = BaseOptions.builder()
                .setDelegate(Delegate.CPU)
                .setModelAssetBuffer(buffer)
                .build()
            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumPoses(1)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener { result, _ -> emit(result) }
                .setErrorListener { error ->
                    lastError = error.message ?: error.toString()
                    onError(lastError)
                }
                .build()
            landmarker = PoseLandmarker.createFromOptions(context, options)
            modelReady = true
            lastError = ""
            true
        } catch (e: Exception) {
            lastError = "model_load_failed: ${e.message}"
            onError(lastError)
            false
        }
    }

    fun start() {
        if (initialize()) started = true
    }

    fun stop() {
        started = false
    }

    fun close() {
        started = false
        modelReady = false
        landmarker?.close()
        landmarker = null
    }

    /// Called from the CameraX ImageAnalysis thread with a frame already
    /// converted to a Bitmap and rotated to display orientation.
    fun process(bitmap: Bitmap, rotationDegrees: Int) {
        val lm = landmarker
        if (!started || lm == null) return
        val rotated = rotate(bitmap, rotationDegrees)
        val startNs = System.nanoTime()
        // MediaPipe requires strictly increasing millisecond timestamps.
        lastTimestampMs = maxOf(System.currentTimeMillis(), lastTimestampMs + 1)
        try {
            lm.detectAsync(BitmapImageBuilder(rotated).build(), lastTimestampMs)
            inferenceCount++
            lastInferenceMs = (System.nanoTime() - startNs) / 1_000_000.0
        } catch (e: Exception) {
            lastError = "inference_failed: ${e.message}"
            onError(lastError)
        }
    }

    private fun rotate(bitmap: Bitmap, degrees: Int): Bitmap {
        if (degrees == 0) return bitmap
        val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun emit(result: PoseLandmarkerResult) {
        val landmarks = result.landmarks().firstOrNull() ?: emptyList()
        val world = result.worldLandmarks().firstOrNull() ?: emptyList()
        val landmarkMaps = landmarks.map { lm ->
            mapOf<String, Any?>(
                "x" to lm.x().toDouble(),
                "y" to lm.y().toDouble(),
                "z" to lm.z().toDouble(),
                "visibility" to (lm.visibility().orElse(0f)).toDouble(),
                "presence" to (lm.presence().orElse(0f)).toDouble(),
            )
        }
        val worldMaps = world.map { lm ->
            mapOf<String, Any?>(
                "x" to lm.x().toDouble(),
                "y" to lm.y().toDouble(),
                "z" to lm.z().toDouble(),
                "visibility" to (lm.visibility().orElse(0f)).toDouble(),
                "presence" to (lm.presence().orElse(0f)).toDouble(),
            )
        }
        onFrame(
            mapOf<String, Any?>(
                "event" to "pose_frame",
                "schema_version" to 1,
                "timestamp_ms" to lastTimestampMs,
                "landmarks" to landmarkMaps,
                "worldLandmarks" to worldMaps,
                "inference_ms" to lastInferenceMs,
            )
        )
    }

    fun status(): Map<String, Any?> = mapOf(
        "running" to running,
        "modelId" to MODEL_ID,
        "backend" to "MediaPipe Tasks Vision 1.2.3 / CPU delegate",
        "modelReady" to modelReady,
        "modelSha256" to EXPECTED_SHA256,
        "inferenceMs" to lastInferenceMs,
        "inferenceCount" to inferenceCount,
        "lastError" to lastError,
    )

    companion object {
        const val MODEL_ID = NativeContract.POSE_MODEL_ID
        const val EXPECTED_SHA256 = NativeContract.POSE_MODEL_SHA256
    }
}
