package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantPageHostDerivedStateGuardTest {
    @Test
    fun rootDelegatesPageHostDerivedStateToShellPolicy() {
        val root = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText()
        val policy = File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantPageHostDerivedState.kt")
            .readText()
        val assistantFactory =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText()
        val mainFactory =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt")
                .readText()

        assertTrue(root.contains("deriveAssistantPageHostState("))
        assertTrue(root.contains("AssistantPageHostDerivedStateInput("))
        assertTrue(root.contains("pageHost = pageHostDerivedState"))
        assertTrue(assistantFactory.contains("effectiveTaskStarted = state.pageHost.effectiveTaskStarted"))
        assertTrue(mainFactory.contains("resultCallId = state.pageHost.resultCallId"))
        assertTrue(mainFactory.contains("runtime.contactAiModel.modelCallContact(state.pageHost.resultCallId)"))

        assertFalse(root.contains("val backendTaskVisible"))
        assertFalse(root.contains("val backendUserText"))
        assertFalse(root.contains("val backendAssistantVisible"))
        assertFalse(root.contains("val effectiveTaskStarted = if"))
        assertFalse(root.contains("val resultCallId = assistantUiState.currentCallId"))

        assertTrue(policy.contains("class AssistantPageHostDerivedStateInput"))
        assertTrue(policy.contains("class AssistantPageHostDerivedState"))
        assertTrue(policy.contains("fun deriveAssistantPageHostState"))
        assertTrue(policy.contains("backendTaskVisible"))
        assertTrue(policy.contains("backendAssistantVisible"))
    }
}
