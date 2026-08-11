package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootTransientOverlayStateTest {
    @Test
    fun consumeAgentPermissionRequestPrefersActiveThenClearsIt() {
        val active = PermissionRequestPayload(permissionKey = "active")
        val fallback = PermissionRequestPayload(permissionKey = "fallback")
        val state = state(activePermission = active)

        val consumed = state.consumeAgentPermissionRequest(fallback)

        assertEquals(active, consumed)
        assertNull(state.activeAgentPermissionRequest)
    }

    @Test
    fun consumeAgentPermissionRequestFallsBackWhenActiveMissing() {
        val fallback = PermissionRequestPayload(permissionKey = "fallback")
        val state = state()

        val consumed = state.consumeAgentPermissionRequest(fallback)

        assertEquals(fallback, consumed)
        assertNull(state.activeAgentPermissionRequest)
    }

    @Test
    fun clearAgentRequestsClearsPermissionAndDocumentOnly() {
        val state = state(
            activePermission = PermissionRequestPayload(permissionKey = "contacts"),
            activeDocument = DocumentImportRequestPayload(reason = "upload"),
            showVoiceModelSheet = true
        )

        state.clearAgentRequests()

        assertNull(state.activeAgentPermissionRequest)
        assertNull(state.activeAgentDocumentRequest)
        assertTrue(state.showVoiceModelSheet)
    }

    @Test
    fun voiceModelSheetVisibilityCanBeSetAndHidden() {
        val state = state()

        state.setVoiceModelSheetVisible(true)
        assertTrue(state.showVoiceModelSheet)

        state.hideVoiceModelSheet()
        assertFalse(state.showVoiceModelSheet)
    }

    @Test
    fun assistantRootScreenDelegatesTransientOverlayState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootTransientOverlayState.kt")
                .readText(Charsets.UTF_8)
        val hostShell =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt")
                .readText(Charsets.UTF_8)
        val permissionRuntime =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPermissionRuntimeShell.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("val transientOverlayState = rootRuntimeGraph.state.transientOverlay"))
        assertTrue(runtimeGraph.contains("rememberAssistantRootTransientOverlayState()"))
        assertTrue(root.contains("transientOverlayState = transientOverlayState"))
        assertFalse(root.contains("transientOverlayState.consumeAgentPermissionRequest"))
        assertTrue(permissionRuntime.contains("deps.transientOverlayState.consumeAgentPermissionRequest"))
        assertTrue(root.contains("transientOverlay = transientOverlayState"))
        assertTrue(hostShell.contains("onUpdateActiveAgentDocumentRequest = state.transientOverlay::updateActiveAgentDocumentRequest"))
        assertTrue(hostShell.contains("onClearAgentDocumentRequest = state.transientOverlay::clearAgentDocumentRequest"))
        assertTrue(hostShell.contains("state.transientOverlay::setVoiceModelSheetVisible"))
        assertTrue(hostShell.contains("state.transientOverlay.showVoiceModelSheet"))
        assertTrue(hostShell.contains("state.transientOverlay::hideVoiceModelSheet"))
        assertFalse(root.contains("mutableStateOf<PermissionRequestPayload?>(null)"))
        assertFalse(root.contains("mutableStateOf<DocumentImportRequestPayload?>(null)"))
        assertFalse(root.contains("var showVoiceModelSheet by rememberSaveable"))
        assertFalse(root.contains("activeAgentPermissionRequest = null"))
        assertFalse(root.contains("activeAgentDocumentRequest = null"))

        assertTrue(holder.contains("rememberSaveable"))
        assertTrue(holder.contains("consumeAgentPermissionRequest"))
        assertTrue(holder.contains("clearAgentRequests"))
    }

    private fun state(
        activePermission: PermissionRequestPayload? = null,
        activeDocument: DocumentImportRequestPayload? = null,
        showVoiceModelSheet: Boolean = false
    ): AssistantRootTransientOverlayState {
        return AssistantRootTransientOverlayState(
            activeAgentPermissionRequestState = mutableStateOf(activePermission),
            activeAgentDocumentRequestState = mutableStateOf(activeDocument),
            showVoiceModelSheetState = mutableStateOf(showVoiceModelSheet)
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
