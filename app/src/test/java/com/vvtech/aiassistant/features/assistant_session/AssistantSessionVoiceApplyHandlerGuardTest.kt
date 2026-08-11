package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionVoiceApplyHandlerGuardTest {
    @Test
    fun voiceSessionApplyFlowLivesInSessionBoundaryHandler() {
        val mapper = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt"
        ).readText(Charsets.UTF_8)
        val handlerFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionVoiceApplyHandler.kt"
        )
        val handler = handlerFile.readText(Charsets.UTF_8)
        val applySessionBody = mapper
            .substringAfter("fun applySession(session: AssistantSessionResponse) {")
            .substringBefore("\n    fun scheduleAutoResumeListening")

        assertTrue(handlerFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(mapper.contains("private val voiceApplyHandler = AssistantSessionVoiceApplyHandler("))
        assertTrue(applySessionBody.contains("voiceApplyHandler.apply(session)"))

        listOf(
            "AssistantSessionApplyStateReducer.reduceVoiceApplyState",
            "AssistantSessionVoicePostApplyContext(",
            "pendingSelectionContinuation = null",
            "pendingFreshTask = false",
            "activeDialogContext = null",
            "viewModel.stopVoiceInteraction()",
            "inferSelectionContinuationFromPreviousSheet"
        ).forEach { token ->
            assertFalse("voice apply flow should not live in SessionMapper: $token", applySessionBody.contains(token))
        }

        listOf(
            "internal class AssistantSessionVoiceApplyHandler",
            "AssistantSessionApplyStateReducer.reduceVoiceApplyState",
            "AssistantSessionVoicePostApplyContext(",
            "setPendingSelectionContinuation(null)",
            "setPendingFreshTask(false)",
            "clearActiveDialogContext()",
            "stopVoiceInteraction()",
            "resolveVoiceSelectionOption",
            "supportsSelectionDrivenDetailSupplement",
            "applySession taskId="
        ).forEach { token ->
            assertTrue("handler should own voice apply flow: $token", handler.contains(token))
        }
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .firstOrNull { it.exists() }
                ?: error("Missing file: $relativePath")
        }
    }
}
