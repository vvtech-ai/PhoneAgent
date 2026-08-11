package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantPermissionOverlayStateTest {
    @Test
    fun defaultsMatchRootPermissionOverlayDefaults() {
        val state = state()

        assertEquals(V88NetworkMode.Normal.name, state.networkModeName)
        assertEquals(V88NetworkMode.Normal, state.networkMode)
        assertFalse(state.showNetworkBlocker)
        assertNull(state.requestedPermissionName)
        assertNull(state.requestedPermission)
        assertEquals("", state.pendingPermissionAction)
        assertFalse(state.microphonePermissionGranted)
        assertFalse(state.storagePermissionGranted)
        assertFalse(state.contactsPermissionGranted)
        assertFalse(state.phonePermissionGranted)
    }

    @Test
    fun derivesNetworkModeAndRequestedPermissionSafely() {
        val state = state()

        state.networkModeName = V88NetworkMode.Offline.name
        state.requestedPermissionName = V88PermissionKind.Contacts.name

        assertEquals(V88NetworkMode.Offline, state.networkMode)
        assertEquals(V88PermissionKind.Contacts, state.requestedPermission)

        state.networkModeName = "bad-network"
        state.requestedPermissionName = "bad-permission"

        assertEquals(V88NetworkMode.Normal, state.networkMode)
        assertNull(state.requestedPermission)
    }

    @Test
    fun pendingPermissionActionIsClearedAfterTake() {
        val state = state()

        state.setPendingPermissionAction("open_contacts", V88PermissionKind.Contacts.name)

        assertEquals(V88PermissionKind.Contacts.name, state.requestedPermissionName)
        assertEquals("open_contacts", state.takePendingPermissionAction())
        assertEquals("", state.pendingPermissionAction)
        assertEquals(V88PermissionKind.Contacts.name, state.requestedPermissionName)

        state.clearRequestedPermission()

        assertNull(state.requestedPermissionName)
        assertEquals("", state.pendingPermissionAction)
    }

    @Test
    fun resetForSessionClearsTransientOverlayStateOnly() {
        val state = state()
        state.showNetworkBlocker()
        state.setPendingPermissionAction("dial", V88PermissionKind.Phone.name)
        state.contactsPermissionGranted = true

        state.resetForSession()

        assertFalse(state.showNetworkBlocker)
        assertNull(state.requestedPermissionName)
        assertEquals("", state.pendingPermissionAction)
        assertTrue(state.contactsPermissionGranted)
    }

    @Test
    fun assistantRootScreenDelegatesPermissionOverlayState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantPermissionOverlayState.kt")
                .readText(Charsets.UTF_8)
        val rootCallEntryAction =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootCallEntryActions.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)
        val contactPermissionRuntime =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootContactPermissionRuntimeShell.kt"
            ).readText(Charsets.UTF_8)

        assertTrue(root.contains("val permissionOverlayState = rootRuntimeGraph.state.permissionOverlay"))
        assertTrue(runtimeGraph.contains("rememberAssistantPermissionOverlayState(context)"))
        assertTrue(root.contains("permissionOverlayState.networkMode"))
        assertTrue(root.contains("permissionOverlayState.requestedPermission"))
        assertFalse(root.contains("permissionOverlayState.takePendingPermissionAction()"))
        assertFalse(root.contains("permissionOverlayState.clearRequestedPermission()"))
        assertFalse(root.contains("permissionOverlayState.showNetworkBlocker()"))
        assertTrue(actionGraph.contains("permissionOverlay.showNetworkBlocker()"))
        assertTrue(rootCallEntryAction.contains("permissionOverlayState.takePendingPermissionAction()"))
        assertTrue(contactPermissionRuntime.contains("permissionOverlayState.clearRequestedPermission()"))

        assertFalse(root.contains("var networkModeName by rememberSaveable"))
        assertFalse(root.contains("var showNetworkBlocker by rememberSaveable"))
        assertFalse(root.contains("var requestedPermissionName by rememberSaveable"))
        assertFalse(root.contains("var pendingPermissionAction by rememberSaveable"))
        assertFalse(root.contains("var microphonePermissionGranted by rememberSaveable"))
        assertFalse(root.contains("var storagePermissionGranted by rememberSaveable"))
        assertFalse(root.contains("var contactsPermissionGranted by rememberSaveable"))
        assertFalse(root.contains("var phonePermissionGranted by rememberSaveable"))

        assertTrue(holder.contains("rememberSaveable { mutableStateOf(V88NetworkMode.Normal.name) }"))
        assertTrue(holder.contains("fun takePendingPermissionAction()"))
        assertTrue(holder.contains("fun resetForSession()"))
    }

    private fun state(): AssistantPermissionOverlayState {
        return AssistantPermissionOverlayState(
            networkModeNameState = mutableStateOf(V88NetworkMode.Normal.name),
            showNetworkBlockerState = mutableStateOf(false),
            requestedPermissionNameState = mutableStateOf<String?>(null),
            pendingPermissionActionState = mutableStateOf(""),
            microphonePermissionGrantedState = mutableStateOf(false),
            storagePermissionGrantedState = mutableStateOf(false),
            contactsPermissionGrantedState = mutableStateOf(false),
            phonePermissionGrantedState = mutableStateOf(false)
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
