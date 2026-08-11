package com.vvtech.aiassistant.features.assistant_settings

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRealtimeCallCloneVoicePresentationTest {
    @Test
    fun mapsMissingReadyAndExpiredCloneStates() {
        assertEquals(
            RealtimeCallCloneVoicePresentation(statusText = "未克隆", actionText = "声音克隆"),
            realtimeCallCloneVoicePresentation(status = null, selected = false)
        )
        assertEquals(
            RealtimeCallCloneVoicePresentation(statusText = "选择", actionText = "重新录制"),
            realtimeCallCloneVoicePresentation(status = "READY", selected = false)
        )
        assertEquals(
            RealtimeCallCloneVoicePresentation(statusText = "当前选择", actionText = "重新录制"),
            realtimeCallCloneVoicePresentation(status = "READY", selected = true)
        )
        assertEquals(
            RealtimeCallCloneVoicePresentation(statusText = "已过期", actionText = "重新录制"),
            realtimeCallCloneVoicePresentation(status = "EXPIRED", selected = false)
        )
    }

    @Test
    fun keepsGeneratingAndFailureStatesVisible() {
        assertEquals(
            RealtimeCallCloneVoicePresentation(statusText = "生成中", actionText = "重新录制"),
            realtimeCallCloneVoicePresentation(status = "PROCESSING", selected = false)
        )
        assertEquals(
            RealtimeCallCloneVoicePresentation(statusText = "生成失败", actionText = "重新录制"),
            realtimeCallCloneVoicePresentation(status = "FAILED", selected = false)
        )
    }

    @Test
    fun mapsCloneDetailCopyForMissingReadyProcessingAndExpiredStates() {
        assertEquals(
            "当前模型暂无可用的克隆音色，完成声音克隆后即可使用",
            realtimeCallCloneVoiceDetail(status = null, hasClone = false, lastError = null)
        )
        assertEquals(
            "当前模型已有可用的克隆音色",
            realtimeCallCloneVoiceDetail(status = "READY", hasClone = true, lastError = null)
        )
        assertEquals(
            "克隆音色正在生成中，完成后可以切换使用",
            realtimeCallCloneVoiceDetail(status = "PROCESSING", hasClone = true, lastError = null)
        )
        assertEquals(
            "服务端提示重新录制",
            realtimeCallCloneVoiceDetail(
                status = "EXPIRED",
                hasClone = true,
                lastError = "服务端提示重新录制"
            )
        )
    }

    @Test
    fun readyCloneKeepsRerecordActionVisibleWithoutEnrollmentFlag() {
        val section = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_settings/" +
                "AssistantRealtimeCallCloneVoiceSection.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(section.contains("showAction = presentation.actionText.isNotBlank()"))
        assertFalse(section.contains("showAction = enrollmentAvailable"))
    }

    private fun sourceFile(path: String): File = listOf(File(path), File("android/app/$path"))
        .first { it.exists() }
}
