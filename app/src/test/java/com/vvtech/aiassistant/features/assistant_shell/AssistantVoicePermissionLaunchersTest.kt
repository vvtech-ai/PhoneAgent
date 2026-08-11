package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoicePermissionLaunchersTest {
    @Test
    fun voiceEntryGrantedWithValidPendingSignal() {
        val harness = Harness(
            entryState = AssistantVoiceEntryPermissionState(
                pendingActive = true,
                pendingAccountId = "account-1"
            )
        )

        handleAssistantVoiceEntryPermissionResult(true, harness.callbacks)

        assertEquals(true, harness.microphoneGranted)
        assertEquals(1, harness.entryGrantedSignals)
        assertEquals(0, harness.entryClearCount)
        assertNull(harness.lastStale)
        assertEquals(0, harness.permissionDeniedCount)
    }

    @Test
    fun voiceEntryGrantedWithStalePendingLogsAndClears() {
        val harness = Harness(
            account = AssistantVoicePermissionAccountState("account-2", mockLoggedIn = true),
            entryState = AssistantVoiceEntryPermissionState(
                pendingActive = true,
                pendingAccountId = "account-1"
            )
        )

        handleAssistantVoiceEntryPermissionResult(true, harness.callbacks)

        assertEquals(true, harness.microphoneGranted)
        assertEquals(0, harness.entryGrantedSignals)
        assertEquals(1, harness.entryClearCount)
        assertEquals("account-1", harness.lastStale?.pendingAccountId)
        assertEquals("account-2", harness.lastStale?.currentAccountId)
    }

    @Test
    fun voiceEntryDeniedClearsAndShowsPermissionMessage() {
        val harness = Harness()

        handleAssistantVoiceEntryPermissionResult(false, harness.callbacks)

        assertEquals(false, harness.microphoneGranted)
        assertEquals(1, harness.entryClearCount)
        assertEquals(1, harness.permissionDeniedCount)
        assertEquals(0, harness.entryGrantedSignals)
    }

    @Test
    fun voiceInteractionGrantedDispatchesByPendingModeAndClears() {
        val toggleHarness = Harness(
            interactionState = AssistantVoiceInteractionPermissionState(
                pendingActive = true,
                pendingAccountId = "account-1",
                forceNewTaskEntry = false,
                useToggle = true
            )
        )
        handleAssistantVoiceInteractionPermissionResult(true, toggleHarness.callbacks)
        assertEquals(listOf("toggle"), toggleHarness.interactionEvents)
        assertEquals(1, toggleHarness.interactionClearCount)

        val forceNewHarness = Harness(
            interactionState = AssistantVoiceInteractionPermissionState(
                pendingActive = true,
                pendingAccountId = "account-1",
                forceNewTaskEntry = true,
                useToggle = false
            )
        )
        handleAssistantVoiceInteractionPermissionResult(true, forceNewHarness.callbacks)
        assertEquals(listOf("startNew"), forceNewHarness.interactionEvents)

        val apiMicHarness = Harness(
            interactionState = AssistantVoiceInteractionPermissionState(
                pendingActive = true,
                pendingAccountId = "account-1",
                forceNewTaskEntry = false,
                useToggle = false
            )
        )
        handleAssistantVoiceInteractionPermissionResult(true, apiMicHarness.callbacks)
        assertEquals(listOf("apiMic"), apiMicHarness.interactionEvents)
    }

    @Test
    fun voiceInteractionStaleOrDeniedDoesNotDispatchAndAlwaysClears() {
        val staleHarness = Harness(
            interactionState = AssistantVoiceInteractionPermissionState(
                pendingActive = true,
                pendingAccountId = "old-account",
                forceNewTaskEntry = true,
                useToggle = false
            )
        )
        handleAssistantVoiceInteractionPermissionResult(true, staleHarness.callbacks)
        assertTrue(staleHarness.interactionEvents.isEmpty())
        assertEquals("old-account", staleHarness.lastStale?.pendingAccountId)
        assertEquals(1, staleHarness.interactionClearCount)

        val deniedHarness = Harness()
        handleAssistantVoiceInteractionPermissionResult(false, deniedHarness.callbacks)
        assertEquals(false, deniedHarness.microphoneGranted)
        assertEquals(1, deniedHarness.permissionDeniedCount)
        assertEquals(1, deniedHarness.interactionClearCount)
        assertTrue(deniedHarness.interactionEvents.isEmpty())
    }

    @Test
    fun rootVoicePermissionCallbackFactoryKeepsStaleLogsAndDispatch() {
        val events = mutableListOf<String>()
        var microphoneGranted: Boolean? = null
        var entryState = AssistantVoiceEntryPermissionState(true, "old-account")
        var interactionState = AssistantVoiceInteractionPermissionState(
            pendingActive = true,
            pendingAccountId = "account-1",
            forceNewTaskEntry = false,
            useToggle = true
        )
        val callbacks = buildAssistantRootVoicePermissionLauncherCallbacks(
            AssistantRootVoicePermissionLauncherCallbackDeps(
                accountProvider = { AssistantVoicePermissionAccountState("account-1", mockLoggedIn = true) },
                voiceEntryStateProvider = { entryState },
                voiceInteractionStateProvider = { interactionState },
                onMicrophonePermissionGrantedChange = { microphoneGranted = it },
                onPermissionDenied = { events += "denied" },
                onVoiceEntryGrantedSignal = { events += "entrySignal" },
                onClearPendingVoiceEntryState = { events += "clearEntry" },
                onClearPendingVoiceInteractionState = { events += "clearInteraction" },
                onToggleVoiceInput = { events += "toggle" },
                onStartNewTaskEntry = { events += "startNew" },
                onApiMicClick = { events += "apiMic" },
                log = { events += "log:$it" }
            )
        )

        handleAssistantVoiceEntryPermissionResult(true, callbacks)
        handleAssistantVoiceInteractionPermissionResult(true, callbacks)

        assertEquals(true, microphoneGranted)
        assertEquals(
            listOf(
                "log:drop stale voice entry permission result pending=true pendingAccount=old-account " +
                    "currentAccount=account-1 loggedIn=true",
                "clearEntry",
                "toggle",
                "clearInteraction"
            ),
            events
        )

        entryState = AssistantVoiceEntryPermissionState(true, "account-1")
        interactionState = interactionState.copy(useToggle = false)
        events.clear()
        handleAssistantVoiceEntryPermissionResult(true, callbacks)
        handleAssistantVoiceInteractionPermissionResult(true, callbacks)

        assertEquals(listOf("entrySignal", "apiMic", "clearInteraction"), events)
    }

    @Test
    fun rootDelegatesVoicePermissionLaunchersToShellHolder() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val holder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantVoicePermissionLaunchers.kt"
        ).readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootVoicePermissionCallbackFactory.kt"
        ).readText(Charsets.UTF_8)
        val permissionRuntime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPermissionRuntimeShell.kt"
        ).readText(Charsets.UTF_8)
        val actionGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(root.contains("rememberLauncherForActivityResult"))
        assertFalse(root.contains("ActivityResultContracts.RequestPermission()"))
        assertTrue(root.contains("rememberAssistantRootPermissionRuntime("))
        assertTrue(root.contains("val voicePermissionLaunchers = permissionRuntime.voicePermissionLaunchers"))
        assertFalse(root.contains("rememberAssistantVoicePermissionLaunchers"))
        assertFalse(root.contains("buildAssistantRootVoicePermissionLauncherCallbacks("))
        assertFalse(root.contains("AssistantRootVoicePermissionLauncherCallbackDeps("))
        assertFalse(root.contains("AssistantVoicePermissionLauncherCallbacks("))
        assertFalse(root.contains("AssistantVoiceEntryPermissionCallbacks("))
        assertFalse(root.contains("AssistantVoiceInteractionPermissionCallbacks("))
        assertFalse(root.contains("drop stale voice entry permission result"))
        assertFalse(root.contains("drop stale voice interaction permission result"))
        assertFalse(root.contains("voicePermissionLaunchers.voiceEntry.launch"))
        assertFalse(root.contains("voicePermissionLaunchers.voiceInteraction.launch"))
        assertTrue(actionGraph.contains("deps.voicePermissionLaunchers.voiceEntry.launch"))
        assertTrue(actionGraph.contains("deps.voicePermissionLaunchers.voiceInteraction.launch"))

        assertTrue(holder.contains("rememberLauncherForActivityResult"))
        assertTrue(holder.contains("ActivityResultContracts.RequestPermission()"))
        assertTrue(holder.contains("handleAssistantVoiceEntryPermissionResult"))
        assertTrue(holder.contains("handleAssistantVoiceInteractionPermissionResult"))
        assertTrue(factory.contains("AssistantVoicePermissionLauncherCallbacks("))
        assertTrue(factory.contains("AssistantVoiceEntryPermissionCallbacks("))
        assertTrue(factory.contains("AssistantVoiceInteractionPermissionCallbacks("))
        assertTrue(factory.contains("drop stale voice entry permission result"))
        assertTrue(factory.contains("drop stale voice interaction permission result"))
        assertTrue(holder.lines().size <= 300)
        assertTrue(factory.lines().size <= 140)
        assertTrue(permissionRuntime.contains("rememberAssistantVoicePermissionLaunchers("))
        assertTrue(permissionRuntime.contains("buildAssistantRootVoicePermissionLauncherCallbacks("))
        assertTrue(permissionRuntime.contains("AssistantRootVoicePermissionLauncherCallbackDeps("))
        assertTrue(permissionRuntime.contains("onClearPendingVoiceEntryState = callbacks.onClearPendingVoiceEntryState"))
        assertTrue(permissionRuntime.lines().size <= 300)
    }

    private class Harness(
        private val account: AssistantVoicePermissionAccountState = AssistantVoicePermissionAccountState(
            currentAccountId = "account-1",
            mockLoggedIn = true
        ),
        private val entryState: AssistantVoiceEntryPermissionState = AssistantVoiceEntryPermissionState(
            pendingActive = false,
            pendingAccountId = ""
        ),
        private val interactionState: AssistantVoiceInteractionPermissionState = AssistantVoiceInteractionPermissionState(
            pendingActive = false,
            pendingAccountId = "",
            forceNewTaskEntry = false,
            useToggle = false
        )
    ) {
        var microphoneGranted: Boolean? = null
        var permissionDeniedCount = 0
        var entryGrantedSignals = 0
        var entryClearCount = 0
        var interactionClearCount = 0
        var lastStale: AssistantVoicePermissionStaleResult? = null
        val interactionEvents = mutableListOf<String>()

        val callbacks = AssistantVoicePermissionLauncherCallbacks(
            accountProvider = { account },
            onMicrophonePermissionGrantedChange = { microphoneGranted = it },
            onPermissionDenied = { permissionDeniedCount += 1 },
            voiceEntry = AssistantVoiceEntryPermissionCallbacks(
                stateProvider = { entryState },
                onGrantedSignal = { entryGrantedSignals += 1 },
                onClearPending = { entryClearCount += 1 },
                onDropStale = { lastStale = it }
            ),
            voiceInteraction = AssistantVoiceInteractionPermissionCallbacks(
                stateProvider = { interactionState },
                onToggleVoiceInput = { interactionEvents += "toggle" },
                onStartNewTaskEntry = { interactionEvents += "startNew" },
                onApiMicClick = { interactionEvents += "apiMic" },
                onClearPending = { interactionClearCount += 1 },
                onDropStale = { lastStale = it }
            )
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
