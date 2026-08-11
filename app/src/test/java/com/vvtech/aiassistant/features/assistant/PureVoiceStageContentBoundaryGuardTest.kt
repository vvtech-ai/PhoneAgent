package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceStageContentBoundaryGuardTest {

    @Test
    fun pureVoiceStageContentDelegatesThreadStateAndListRendering() {
        val content = File("src/main/java/com/vvtech/aiassistant/features/assistant/PureVoiceStageContent.kt").readText()
        val renderState = File("src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceThreadRenderState.kt").readText()
        val threadList = File("src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceThreadList.kt").readText()

        assertTrue(
            "PureVoiceStageContent should build a render state instead of deriving all thread fields inline.",
            content.contains("buildPureVoiceThreadRenderState(") &&
                content.contains("PureVoiceStageContentArgs") &&
                renderState.contains("data class PureVoiceThreadRenderState") &&
                renderState.contains("fun buildPureVoiceThreadRenderState(")
        )
        assertTrue(
            "PureVoiceStageContent should delegate thread list rendering to PureVoiceThreadList.",
            content.contains("PureVoiceThreadList(") &&
                threadList.contains("LazyColumn(") &&
                threadList.contains("PureVoiceAssistantStepItem")
        )
        assertFalse(
            "PureVoiceStageContent should not own LazyColumn item rendering after the shell split.",
            content.contains("LazyColumn(") ||
                content.contains("itemsIndexed(") ||
                content.contains("visibleLiveAssistant?.let")
        )
        assertFalse(
            "The hard-disabled legacy auto-card branch should stay removed from the pure voice content shell.",
            content.contains("renderLegacyAutoCards") ||
                threadList.contains("renderLegacyAutoCards") ||
                renderState.contains("renderLegacyAutoCards")
        )
    }
}
