package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslationDialLifecycleBoundaryGuardTest {
    @Test
    fun translationFinalizationUsesAttemptIdentityAndSourceAwareReturn() {
        val controller = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantTranslationCallRuntimeController.kt"
        ).readText(Charsets.UTF_8)
        val runtimeGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt"
        ).readText(Charsets.UTF_8)
        val recordState = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantCallRecordState.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(controller.contains("callLifecycle.tryFinalize("))
        assertTrue(controller.contains("callId = recordCallId"))
        assertTrue(controller.contains("exitPage(failedStatus, recordResult = true, attemptId = attemptId)"))
        assertTrue(controller.contains("response.callId.isBlank()"))
        assertTrue(controller.contains("callbacks.onNavigateAfterExit(finalization.origin)"))
        assertTrue(runtimeGraph.contains("origin == TranslationCallOrigin.DIALER"))
        assertTrue(runtimeGraph.contains("navigationState.applyMainTab(FinalMainTab.Calls)"))
        assertTrue(recordState.contains("appendIfAbsentForAccount"))
    }

    private fun sourceFile(path: String): File {
        return listOf(File(path), File("android/app/$path")).first { it.exists() }
    }
}
