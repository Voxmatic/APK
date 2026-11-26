package com.aitrainer.gymtrainer.ai_gym_trainer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var plugin: AiTrainerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        plugin = AiTrainerPlugin(this).also { it.register(flutterEngine) }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        plugin?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        plugin?.close()
        super.onDestroy()
    }
}
