package com.aitrainer.gymtrainer.ai_gym_trainer

/// Pure Kotlin contract shared by the native bridge and its JVM unit tests.
/// It has no Android dependencies so it can be verified without a device.
object NativeContract {
    const val SCHEMA_VERSION = 1
    const val CAMERA_CHANNEL = "ai_gym_trainer/camera"
    const val POSE_CHANNEL = "ai_gym_trainer/pose"
    const val SYSTEM_CHANNEL = "ai_gym_trainer/system"
    const val CAMERA_VIEW_TYPE = "ai_gym_trainer/camera_view"
    const val POSE_MODEL_ID = "pose_landmarker_lite"
    const val POSE_MODEL_SHA256 =
        "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a"
}
