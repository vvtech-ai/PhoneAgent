package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallMonitorContractTest {
    @Test
    fun monitorChannelIsReadOnlyAndUiUsesIndependentState() {
        val client = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_audio/CallMonitorAudioSocketClient.kt"
        ).readText(Charsets.UTF_8)
        val handler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt"
        ).readText(Charsets.UTF_8)
        val routeManager = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_audio/CallMonitorAudioRouteManager.kt"
        ).readText(Charsets.UTF_8)
        val page = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalAiCallPage.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(client.contains("import android.media.AudioRecord"))
        assertFalse(client.contains("AudioRecord("))
        assertTrue(client.contains("/ws/assistant/call/monitor?ticket="))
        assertTrue(handler.contains("callMonitorController.toggle()"))
        assertTrue(handler.contains("takeoverAudioController.setCaptureEnabled(enabled)"))
        assertTrue(page.contains("callMonitorState == CallMonitorPlaybackState.Playing"))
        assertTrue(page.contains("label = \"监听\""))
        assertTrue(page.contains("label = \"挂断\""))
        assertFalse(page.contains("label = \"接管\""))
        assertTrue(page.contains("callMonitorAudioRouteState.selected.displayLabel()"))
        assertTrue(routeManager.contains("AudioDeviceCallback"))
        assertTrue(routeManager.contains("setCommunicationDevice"))
        assertTrue(routeManager.contains("bluetooth_disconnected_fallback_earpiece"))
    }

    private fun sourceFile(relativePath: String): File {
        return generateSequence(File(".").absoluteFile) { it.parentFile }
            .map { File(it, relativePath) }
            .first { it.exists() }
    }
}
