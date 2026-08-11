package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeComposerStateTest {
    @Test
    fun defaultsMatchRootComposerDefaults() {
        val state = state()

        assertFalse(state.isOpen)
        assertEquals("Voice", state.modeName)
    }

    @Test
    fun showCloseAndModeUpdateUseSingleHolder() {
        val state = state()

        state.show()
        state.updateModeName("Text")
        state.close()

        assertFalse(state.isOpen)
        assertEquals("Text", state.modeName)

        state.isOpen = true

        assertTrue(state.isOpen)
    }

    @Test
    fun assistantRootScreenDelegatesHomeComposerState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantHomeComposerState.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)
        val authResetBinder =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootAuthResetCallbackBinder.kt"
            ).readText(Charsets.UTF_8)
        val assistantFactory =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val homeComposerState = rootRuntimeGraph.state.homeComposer"))
        assertTrue(runtimeGraph.contains("rememberAssistantHomeComposerState(ComposerMode.Voice.name)"))
        assertFalse(root.contains("onCloseHomeComposer = homeComposerState::close"))
        assertTrue(authResetBinder.contains("onCloseHomeComposer = homeComposerState::close"))
        assertFalse(root.contains("onShowHomeComposer = homeComposerState::show"))
        assertTrue(actionGraph.contains("onShowHomeComposer = state.homeComposer::show"))
        assertTrue(root.contains("homeComposer = homeComposerState"))
        assertTrue(assistantFactory.contains("homeComposerOpen = state.homeComposer.isOpen"))
        assertTrue(assistantFactory.contains("composerMode = state.homeComposer.modeName"))
        assertTrue(assistantFactory.contains("onHomeComposerOpenChange = { state.homeComposer.isOpen = it }"))
        assertTrue(assistantFactory.contains("onComposerModeChange = state.homeComposer::updateModeName"))

        assertFalse(root.contains("var homeComposerOpen by rememberSaveable"))
        assertFalse(root.contains("var composerMode by rememberSaveable"))
        assertTrue(holder.contains("rememberSaveable { mutableStateOf(false) }"))
        assertTrue(holder.contains("rememberSaveable { mutableStateOf(defaultModeName) }"))
    }

    private fun state(defaultModeName: String = "Voice"): AssistantHomeComposerState {
        return AssistantHomeComposerState(
            openState = mutableStateOf(false),
            modeNameState = mutableStateOf(defaultModeName)
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
