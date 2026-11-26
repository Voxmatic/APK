package com.aitrainer.gymtrainer.ai_gym_trainer

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.view.View
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/// Single bridge between Flutter and native camera / pose / secure storage.
class AiTrainerPlugin(private val activity: io.flutter.embedding.android.FlutterActivity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private val previewView by lazy { PreviewView(activity) }
    private val poseProcessor by lazy {
        PoseProcessor(
            activity,
            { map -> sink?.success(map) },
            { error -> sink?.error("INFERENCE_ERROR", error, null) },
        )
    }
    private val crypto by lazy { SecureCrypto(activity) }
    private val cameraController by lazy {
        CameraController(activity, previewView) { bitmap, rotation ->
            poseProcessor.process(bitmap, rotation)
        }
    }

    fun register(engine: FlutterEngine) {
        val messenger: DartExecutor = engine.dartExecutor
        MethodChannel(messenger.binaryMessenger, CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger.binaryMessenger, EVENT_CHANNEL).setStreamHandler(this)
        engine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    return object : PlatformView {
                        override fun getView(): View = previewView
                        override fun dispose() {
                            cameraController.stop()
                            poseProcessor.stop()
                        }
                    }
                }
            },
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "camera.requestPermission" -> {
                if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
                    PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(mapOf("granted" to true))
                } else {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.CAMERA),
                        REQUEST_CAMERA,
                    )
                    result.success(mapOf("granted" to false, "pending" to true))
                }
            }
            "camera.initialize" -> result.success(mapOf("ok" to cameraController.initialize()))
            "camera.start" -> {
                cameraController.start()
                poseProcessor.start()
                result.success(mapOf("ok" to true))
            }
            "camera.stop" -> {
                cameraController.stop()
                poseProcessor.stop()
                result.success(mapOf("ok" to true))
            }
            "camera.getStatus" -> result.success(
                mapOf<String, Any?>(
                    "running" to cameraController.isRunning(),
                    "permission" to (
                            ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
                                    PackageManager.PERMISSION_GRANTED
                            ),
                    "fps" to 30.0,
                )
            )
            "pose.getStatus" -> result.success(poseProcessor.status())
            "storage.encrypt" -> {
                val text = call.arguments as? String ?: ""
                result.success(crypto.encrypt(text))
            }
            "storage.decrypt" -> {
                @Suppress("UNCHECKED_CAST")
                val payload = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                try {
                    result.success(crypto.decrypt(payload))
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CAMERA) return
        // The UI polls camera.getStatus after the permission dialog closes.
    }

    fun close() {
        cameraController.close()
        poseProcessor.close()
    }

    companion object {
        const val CHANNEL = "ai_gym_trainer/camera"
        const val EVENT_CHANNEL = "ai_gym_trainer/pose"
        const val VIEW_TYPE = "ai_gym_trainer/camera_view"
        const val REQUEST_CAMERA = 1001
    }
}
