package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionTextApplyHandlerGuardTest {
    @Test
    fun textSessionApplyFlowLivesInSessionBoundaryHandler() {
        val mapper = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt"
        ).readText(Charsets.UTF_8)
        val handlerFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionTextApplyHandler.kt"
        )
        val handler = handlerFile.readText(Charsets.UTF_8)
        val applyTextBody = mapper
            .substringAfter("fun applyTextSession(session: AssistantSessionResponse) {")
            .substringBefore("\n    fun applySession(session: AssistantSessionResponse) {")

        assertTrue(handlerFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(mapper.contains("private val textApplyHandler = AssistantSessionTextApplyHandler("))
        assertTrue(applyTextBody.contains("textApplyHandler.apply(session)"))

        listOf(
            "AssistantSessionApplyStateReducer.reduceTextApplyState",
            "pendingSelectionContinuation = null",
            "textTaskId = null",
            "activeInteractionChannel = InteractionChannel.NONE",
            "shouldPreserveTerminalResult(session)",
            "resetToIdleHome()",
            "refreshHistory()"
        ).forEach { token ->
            assertFalse("text apply flow should not live in SessionMapper: $token", applyTextBody.contains(token))
        }

        listOf(
            "internal class AssistantSessionTextApplyHandler",
            "AssistantSessionApplyStateReducer.reduceTextApplyState",
            "setPendingSelectionContinuation(null)",
            "setTextTaskId(null)",
            "setActiveInteractionChannel(InteractionChannel.NONE)",
            "shouldPreserveTerminalResult(session)",
            "deps.actions.resetToIdleHome()",
            "deps.actions.refreshHistory()"
        ).forEach { token ->
            assertTrue("handler should own text apply flow: $token", handler.contains(token))
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
