package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTaskPageRefreshStateTest {
    @Test
    fun markTaskPageEnteredBumpsSignal() {
        val state = state()

        state.markTaskPageEntered()
        state.markTaskPageEntered()

        assertEquals(2L, state.taskPageEnteredSignal)
    }

    @Test
    fun nextDeferredRefreshIdUsesIncrementingSequence() {
        val state = state()

        assertEquals("single_flow-1", state.nextDeferredRefreshId("single_flow"))
        assertEquals("single_flow-2", state.nextDeferredRefreshId("single_flow"))
        assertEquals("system_back-3", state.nextDeferredRefreshId("system_back"))
    }

    @Test
    fun assistantRootScreenDelegatesTaskPageRefreshState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantTaskPageRefreshState.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val taskPageRefreshState = rootRuntimeGraph.state.taskPageRefresh"))
        assertTrue(runtimeGraph.contains("rememberAssistantTaskPageRefreshState()"))
        assertTrue(primaryShell.contains("taskPageRefreshState::nextDeferredRefreshId"))
        assertTrue(root.contains("taskPageRefreshState.taskPageEnteredSignal"))
        assertTrue(root.contains("taskPageRefreshState::markTaskPageEntered"))
        assertTrue(root.contains("AssistantTaskDeferredRefreshShellEffect("))
        assertTrue(root.contains("AssistantTaskDeferredRefreshShellEffectArgs("))
        assertFalse(root.contains("FinalDeferredTaskRefreshEffect("))
        assertFalse(root.contains("FinalDeferredTaskRefreshEffectArgs("))
        assertFalse(root.contains("var taskPageEnteredSignal by remember"))
        assertFalse(root.contains("var deferredRefreshSequence by rememberSaveable"))
        assertFalse(root.contains("fun nextDeferredRefreshId(source: String): String"))

        assertTrue(holder.contains("remember { mutableStateOf(0L) }"))
        assertTrue(holder.contains("rememberSaveable { mutableStateOf(0L) }"))
        assertTrue(holder.contains("class AssistantTaskDeferredRefreshShellEffectArgs"))
        assertTrue(holder.contains("fun AssistantTaskDeferredRefreshShellEffect"))
        assertTrue(holder.contains("FinalDeferredTaskRefreshEffect("))
        assertTrue(holder.contains("FinalDeferredTaskRefreshEffectArgs("))
    }

    private fun state(): AssistantTaskPageRefreshState {
        return AssistantTaskPageRefreshState(
            taskPageEnteredSignalState = mutableStateOf(0L),
            deferredRefreshSequenceState = mutableStateOf(0L)
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
