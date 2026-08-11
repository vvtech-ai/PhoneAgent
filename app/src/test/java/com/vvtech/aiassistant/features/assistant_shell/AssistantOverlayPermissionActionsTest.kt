package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantOverlayPermissionActionsTest {
    @Test
    fun offlineNetworkRetryShowsMessageWithoutDismissingBlocker() {
        val events = mutableListOf<String>()

        handleOverlayNetworkRetry(
            state = AssistantOverlayPermissionActionState(networkMode = V88NetworkMode.Offline),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("message:当前仍为断网模拟，可在开发者功能切换"), events)
    }

    @Test
    fun normalNetworkRetryDismissesBlocker() {
        val events = mutableListOf<String>()

        handleOverlayNetworkRetry(
            state = AssistantOverlayPermissionActionState(networkMode = V88NetworkMode.Normal),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("network:false"), events)
    }

    @Test
    fun microphoneAllowGrantsPermissionAndRunsPendingAction() {
        val events = mutableListOf<String>()

        handleOverlayPermissionAllow(V88PermissionKind.Microphone, callbacks(events))

        assertEquals(
            listOf("microphone:true", "requested:null", "runPending"),
            events
        )
    }

    @Test
    fun contactsAllowLaunchesContactsPermissionWithoutRunningPendingAction() {
        val events = mutableListOf<String>()

        handleOverlayPermissionAllow(V88PermissionKind.Contacts, callbacks(events))

        assertEquals(listOf("requested:null", "launchContacts"), events)
    }

    @Test
    fun contactsDenyClearsPendingActionAndKeepsCurrentPage() {
        val events = mutableListOf<String>()

        handleOverlayPermissionDeny(V88PermissionKind.Contacts, callbacks(events))

        assertTrue(events.first().startsWith("message:需要"))
        assertTrue(events.first().endsWith("才能使用此功能"))
        assertEquals("requested:null", events[1])
        assertEquals("pending:", events[2])
        assertFalse(events.contains("goHome"))
    }

    @Test
    fun phoneDenyDoesNotGoHome() {
        val events = mutableListOf<String>()

        handleOverlayPermissionDeny(V88PermissionKind.Phone, callbacks(events))

        assertFalse(events.contains("goHome"))
        assertEquals("requested:null", events[1])
        assertEquals("pending:", events[2])
    }

    @Test
    fun pendingPermissionActionsDispatchKnownActions() {
        val events = mutableListOf<String>()
        val callbacks = pendingCallbacks(events)

        assertTrue(runAssistantPendingPermissionAction("dial", callbacks))
        assertTrue(runAssistantPendingPermissionAction("translation_dial", callbacks))
        assertTrue(runAssistantPendingPermissionAction("contact_call", callbacks))
        assertTrue(runAssistantPendingPermissionAction("upload_attachment", callbacks))

        assertEquals(
            listOf("dial", "translationDial", "contactCall", "attachmentUploaded"),
            events
        )
    }

    @Test
    fun pendingPermissionActionsIgnoreOpenContactsAndUnknown() {
        val events = mutableListOf<String>()
        val callbacks = pendingCallbacks(events)

        assertFalse(runAssistantPendingPermissionAction("open_contacts", callbacks))
        assertFalse(runAssistantPendingPermissionAction("unknown", callbacks))

        assertTrue(events.isEmpty())
    }

    @Test
    fun contactsUseDedicatedCurrentStyleWhileOtherPermissionsStayLegacy() {
        assertEquals(
            AssistantPermissionDialogPresentation.Contact,
            assistantPermissionDialogPresentation(V88PermissionKind.Contacts)
        )
        listOf(
            V88PermissionKind.Microphone,
            V88PermissionKind.Storage,
            V88PermissionKind.Phone
        ).forEach { permission ->
            assertEquals(
                AssistantPermissionDialogPresentation.Legacy,
                assistantPermissionDialogPresentation(permission)
            )
        }
    }

    @Test
    fun rootDelegatesPendingPermissionActionToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantOverlayPermissionActions.kt"
        ).readText(Charsets.UTF_8)
        val rootCallEntryAction = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootCallEntryActions.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(root.contains("callEntryActions::runPendingPermissionAction"))
        assertTrue(hostShell.contains("actions.callEntry::runPendingPermissionAction"))
        assertFalse(root.contains("runAssistantPendingPermissionAction("))
        assertFalse(root.contains("permissionOverlayState.takePendingPermissionAction()"))
        assertFalse(root.contains("when (action)"))
        assertFalse(root.contains("\"upload_attachment\" -> taskEntry.confirmAttachmentUploaded = true"))

        assertTrue(action.contains("runAssistantPendingPermissionAction"))
        assertTrue(rootCallEntryAction.contains("runAssistantPendingPermissionAction("))
        assertTrue(rootCallEntryAction.contains("permissionOverlayState.takePendingPermissionAction()"))
        assertTrue(action.lines().size <= 300)
    }

    private fun callbacks(events: MutableList<String>) = AssistantOverlayPermissionActionCallbacks(
        onShowMessage = { events += "message:$it" },
        onShowNetworkBlockerChange = { events += "network:$it" },
        onRequestedPermissionNameChange = { events += "requested:${it ?: "null"}" },
        onPendingPermissionActionChange = { events += "pending:$it" },
        onMicrophonePermissionGrantedChange = { events += "microphone:$it" },
        onStoragePermissionGrantedChange = { events += "storage:$it" },
        onContactsPermissionGrantedChange = { events += "contacts:$it" },
        onPhonePermissionGrantedChange = { events += "phone:$it" },
        onLaunchContactsPermission = { events += "launchContacts" },
        onRunPendingPermissionAction = { events += "runPending" },
        onGoHomeAfterContactsDenied = { events += "goHome" }
    )

    private fun pendingCallbacks(events: MutableList<String>) = AssistantPendingPermissionActionCallbacks(
        onRunDial = { events += "dial" },
        onRunTranslationDial = { events += "translationDial" },
        onRunContactCall = { events += "contactCall" },
        onConfirmAttachmentUploaded = { events += "attachmentUploaded" }
    )

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
