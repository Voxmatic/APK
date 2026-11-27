package com.aitrainer.gymtrainer.ai_gym_trainer

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import android.view.View
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.security.MessageDigest
import java.util.Locale

/// Single bridge between Flutter and native camera / pose / secure storage.
/// Every method returns a map with `ok`; no exception reaches Dart uncaught.
class AiTrainerPlugin(private val activity: FlutterActivity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private var systemSink: EventChannel.EventSink? = null
    private val poseProcessor by lazy {
        PoseProcessor(
            activity,
            { map -> sink?.success(map) },
            { error -> emitEvent("INFERENCE_ERROR", error) },
        )
    }
    private val crypto by lazy { SecureCrypto(activity) }
    private val cameraController by lazy {
        CameraController(activity) { bitmap, rotation ->
            poseProcessor.process(bitmap, rotation)
        }
    }

    fun register(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        EventChannel(messenger, SYSTEM_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                systemSink = events
            }

            override fun onCancel(arguments: Any?) {
                systemSink = null
            }
        })
        engine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
                    createPreviewView()
            },
        )
    }

    /// Each Flutter platform-view id receives its own native view. The camera
    /// controller is bound only after attach; disposal stops only the active view.
    private fun createPreviewView(): PlatformView {
        val view = PreviewView(activity)
        cameraController.bind(view)
        return object : PlatformView {
            override fun getView(): View = view

            override fun dispose() {
                if (cameraController.isBoundTo(view)) {
                    cameraController.stop()
                    poseProcessor.stop()
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "camera.requestPermission" -> {
                if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
                    PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(mapOf("ok" to true, "granted" to true))
                } else {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.CAMERA),
                        REQUEST_CAMERA,
                    )
                    result.success(mapOf("ok" to true, "granted" to false, "pending" to true))
                }
            }
            "camera.initialize" -> result.success(cameraController.initialize())
            "camera.start" -> {
                val cameraResult = cameraController.start()
                if (cameraResult["ok"] == true) poseProcessor.start()
                result.success(cameraResult)
            }
            "camera.stop" -> {
                poseProcessor.stop()
                result.success(cameraController.stop())
            }
            "camera.getStatus" -> result.success(cameraController.status())
            "pose.getStatus" -> result.success(poseProcessor.status())
            "pose.unload" -> {
                poseProcessor.close()
                result.success(mapOf("ok" to true))
            }
            "device.getInfo" -> result.success(deviceInfo())
            "storage.getFreeSpace" -> result.success(mapOf("bytes" to freeStorageBytes()))
            "app.openSettings" -> {
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${activity.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                result.success(mapOf("ok" to true))
            }
            "storage.encrypt" -> {
                val text = call.arguments as? String
                if (text == null) {
                    result.error("STORAGE_ERROR", "Expected string payload", null)
                } else {
                    try {
                        result.success(crypto.encrypt(text))
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
            }
            "storage.decrypt" -> {
                @Suppress("UNCHECKED_CAST")
                val payload = call.arguments as? Map<*, *>
                if (payload == null) {
                    result.error("STORAGE_ERROR", "Expected encrypted envelope", null)
                } else {
                    try {
                        result.success(crypto.decrypt(payload))
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
            }
            "model.register" -> result.success(registerModelFile(call))
            "model.delete" -> result.success(deleteModelFile(call))
            else -> result.notImplemented()
        }
    }

    private fun deviceInfo(): Map<String, Any?> {
        val manager = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        return mapOf(
            "platform" to "android",
            "model" to Build.MODEL,
            "osVersion" to Build.VERSION.RELEASE,
            "sdk" to Build.VERSION.SDK_INT,
            "abi" to Build.SUPPORTED_ABIS.firstOrNull(),
            "totalRamBytes" to info.totalMem,
            "freeStorageBytes" to freeStorageBytes(),
            "cameraAvailable" to activity.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
            "acceleration" to "CPU (MediaPipe Tasks delegate)",
        )
    }

    private fun freeStorageBytes(): Long {
        val path = activity.filesDir.path
        val stat = StatFs(path)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            stat.availableBlocksLong * stat.blockSizeLong
        } else {
            stat.availableBlocks.toLong() * stat.blockSize.toLong()
        }
    }

    private fun registerModelFile(call: MethodCall): Map<String, Any?> {
        val id = call.argument<String>("id") ?: return mapOf("ok" to false, "message" to "Missing id")
        val path = call.argument<String>("path")
            ?: return mapOf("ok" to false, "message" to "Missing path")
        val file = File(path)
        if (!file.exists() || !file.canRead()) {
            return mapOf("ok" to false, "message" to "Model file not found: $path")
        }
        val bytes = file.readBytes()
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        val sha = digest.joinToString("") { "%02x".format(Locale.ROOT, it) }
        return mapOf("ok" to true, "id" to id, "size" to bytes.size, "sha256" to sha)
    }

    private fun deleteModelFile(call: MethodCall): Map<String, Any?> {
        val path = call.argument<String>("path")
            ?: return mapOf("ok" to false, "message" to "Missing path")
        val file = File(path)
        val deleted = if (file.exists()) file.delete() else true
        return mapOf("ok" to deleted, "message" to if (deleted) "Removed" else "Delete failed")
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emitEvent(code: String, message: String) {
        systemSink?.success(
            mapOf(
                "type" to "lifecycle",
                "phase" to "error",
                "message" to "$code: $message",
            ),
        )
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CAMERA) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        systemSink?.success(
            mapOf(
                "type" to "permission",
                "granted" to granted,
                "message" to if (granted) "granted" else "denied",
            ),
        )
    }

    fun onHostPause() {
        cameraController.stop()
        poseProcessor.stop()
        systemSink?.success(mapOf("type" to "lifecycle", "phase" to "paused"))
    }

    fun onHostResume() {
        systemSink?.success(mapOf("type" to "lifecycle", "phase" to "resumed"))
    }

    fun onHostStop() {
        cameraController.stop()
        poseProcessor.stop()
        systemSink?.success(mapOf("type" to "lifecycle", "phase" to "detached"))
    }

    fun onLowMemory() {
        poseProcessor.close()
        systemSink?.success(
            mapOf("type" to "lifecycle", "phase" to "low_memory", "message" to "Model unloaded"),
        )
    }

    fun close() {
        cameraController.close()
        poseProcessor.close()
    }

    companion object {
        const val CHANNEL = NativeContract.CAMERA_CHANNEL
        const val EVENT_CHANNEL = NativeContract.POSE_CHANNEL
        const val SYSTEM_CHANNEL = NativeContract.SYSTEM_CHANNEL
        const val VIEW_TYPE = NativeContract.CAMERA_VIEW_TYPE
        const val REQUEST_CAMERA = 1001
    }
}
