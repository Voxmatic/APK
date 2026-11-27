package com.aitrainer.gymtrainer.ai_gym_trainer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class NativeContractTest {
    @Test
    fun `channel names match the Dart bridge contract`() {
        assertEquals("ai_gym_trainer/camera", NativeContract.CAMERA_CHANNEL)
        assertEquals("ai_gym_trainer/pose", NativeContract.POSE_CHANNEL)
        assertEquals("ai_gym_trainer/system", NativeContract.SYSTEM_CHANNEL)
        assertEquals("ai_gym_trainer/camera_view", NativeContract.CAMERA_VIEW_TYPE)
        assertEquals(1, NativeContract.SCHEMA_VERSION)
    }

    @Test
    fun `pinned pose checksum matches the bundled manifest`() {
        val manifest = File("../../assets/models/manifest.json").readText()
        val poseBlock = manifest.substringAfter("\"id\": \"pose_landmarker_lite\"")
            .substringBefore("\"id\":")
        assertTrue(poseBlock.contains(NativeContract.POSE_MODEL_SHA256))
        assertEquals(64, NativeContract.POSE_MODEL_SHA256.length)
        assertTrue(NativeContract.POSE_MODEL_SHA256.matches(Regex("[0-9a-f]{64}")))
    }
}
