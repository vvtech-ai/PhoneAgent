package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantVoiceEntryActionsTest {
    @Test
    fun voiceInteractionWithoutMicrophonePermissionSavesPendingAndLaunchesPermission() {
        val harness = Harness(microphoneGranted = false)

        val handled = startAssistantVoiceInteractionWithPermission(
            request = AssistantVoiceInteractionStartRequest(forceNewTaskEntry = true, useToggle = false),
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            dispatch = harness.dispatchCallbacks
        )

        assertTrue(handled)
        assertEquals("account-1", harness.interactionPending?.accountId)
        assertEquals(true, harness.interactionPending?.forceNewTaskEntry)
        assertEquals(listOf("micGranted:false", "launchInteractionPermission"), harness.events)
    }

    @Test
    fun voiceInteractionWithMicrophonePermissionDispatchesByMode() {
        val toggle = Harness(microphoneGranted = true)
        startAssistantVoiceInteractionWithPermission(
            AssistantVoiceInteractionStartRequest(forceNewTaskEntry = false, useToggle = true),
            toggle.accountCallbacks,
            toggle.permissionCallbacks,
            toggle.pendingCallbacks,
            toggle.dispatchCallbacks
        )
        assertEquals(listOf("micGranted:true", "toggle"), toggle.events)

        val forceNew = Harness(microphoneGranted = true)
        startAssistantVoiceInteractionWithPermission(
            AssistantVoiceInteractionStartRequest(forceNewTaskEntry = true, useToggle = false),
            forceNew.accountCallbacks,
            forceNew.permissionCallbacks,
            forceNew.pendingCallbacks,
            forceNew.dispatchCallbacks
        )
        assertEquals(listOf("micGranted:true", "startNew"), forceNew.events)
    }

    @Test
    fun startVoiceEntryWithoutMicrophonePermissionSavesTrimmedPendingAndLaunchesPermission() {
        val harness = Harness(microphoneGranted = false)

        val handled = startAssistantVoiceEntry(
            request = AssistantVoiceEntryStartRequest(
                initialCommand = "  book table  ",
                startWithVoice = true,
                resumeExisting = false,
                initialSkillId = "restaurant_booking"
            ),
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertTrue(handled)
        assertEquals("book table", harness.pending.initialCommand)
        assertTrue(harness.pending.active)
        assertEquals("account-1", harness.pending.accountId)
        assertEquals("restaurant_booking", harness.pending.initialSkillId)
        assertEquals(listOf("blockOffline:false", "blockIdentity:false", "micGranted:false", "launchEntryPermission"), harness.events)
    }

    @Test
    fun identityBlockKeepsExactSkillPendingAndDoesNotRequestMicrophone() {
        val harness = Harness(microphoneGranted = false, identityIncomplete = true)

        val handled = startAssistantVoiceEntry(
            request = AssistantVoiceEntryStartRequest(
                initialCommand = "预订餐厅",
                startWithVoice = true,
                resumeExisting = false,
                initialSkillId = "restaurant_booking"
            ),
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertTrue(handled)
        assertTrue(harness.pending.active)
        assertEquals("restaurant_booking", harness.pending.initialSkillId)
        assertEquals(
            listOf("blockOffline:false", "blockIdentity:true"),
            harness.events
        )
    }

    @Test
    fun identityCompletionResumesPendingSkillThenRequestsMicrophone() {
        val harness = Harness(microphoneGranted = false)
        harness.pending = pending(
            initialCommand = "预订餐厅",
            active = true,
            accountId = "account-1",
            initialSkillId = "restaurant_booking"
        )

        val handled = continueAssistantVoiceEntryAfterIdentityCompleted(
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertTrue(handled)
        assertTrue(harness.pending.active)
        assertEquals("restaurant_booking", harness.pending.initialSkillId)
        assertEquals(listOf("micGranted:false", "launchEntryPermission"), harness.events)
    }

    @Test
    fun contactAndSkillSurviveIdentityAndMicrophoneGatesIntoNewFlow() {
        val harness = Harness(microphoneGranted = false, identityIncomplete = true)
        val selectedContact = SelectedContactTaskContext.contactDetail(
            name = "张三",
            phone = "13800138000"
        )

        startAssistantVoiceEntry(
            request = AssistantVoiceEntryStartRequest(
                initialCommand = null,
                startWithVoice = true,
                resumeExisting = false,
                initialSkillId = "restaurant_booking",
                initialSkillOpening = "想订哪家餐厅？",
                selectedContact = selectedContact
            ),
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertEquals(selectedContact, harness.pending.selectedContact)
        harness.identityIncomplete = false
        continueAssistantVoiceEntryAfterIdentityCompleted(
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )
        assertEquals(selectedContact, harness.pending.selectedContact)

        harness.microphoneGranted = true
        continueAssistantVoiceEntryAfterMicrophoneGranted(
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertEquals("restaurant_booking", harness.openedPlan?.initialSkillId)
        assertEquals("想订哪家餐厅？", harness.openedPlan?.initialSkillOpening)
        assertEquals(selectedContact, harness.openedPlan?.selectedContact)
        assertFalse(harness.pending.active)
    }

    @Test
    fun continueAfterMicrophoneGrantedBypassesVoiceCloneGuideAndOpensFlow() {
        val harness = Harness()
        harness.pending = pending(active = true, accountId = "account-1")

        val handled = continueAssistantVoiceEntryAfterMicrophoneGranted(
            account = harness.accountCallbacks,
            permission = harness.permissionCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertTrue(handled)
        assertFalse(harness.pending.active)
        assertEquals(
            listOf(
                "micGranted:true",
                "blockIdentity:false",
                "blockIdentity:false",
                "reset:open_pending_voice_entry",
                "clearLocalTaskItems",
                "openNew::true:true",
                "clearPending"
            ),
            harness.events
        )
    }

    @Test
    fun openPendingVoiceEntryResumeExistingOnlyOpensAndClears() {
        val harness = Harness()
        harness.pending = pending(active = true, accountId = "account-1", resumeExisting = true)

        val handled = openAssistantPendingVoiceEntry(
            account = harness.accountCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertTrue(handled)
        assertFalse(harness.pending.active)
        assertEquals(listOf("blockIdentity:false", "openExisting", "clearPending"), harness.events)
    }

    @Test
    fun openPendingVoiceEntryNewFlowKeepsLegacyOrder() {
        val harness = Harness()
        harness.pending = pending(
            initialCommand = "",
            startInVoice = true,
            active = true,
            accountId = "account-1",
            initialSkillId = "restaurant_booking"
        )

        val handled = openAssistantPendingVoiceEntry(
            account = harness.accountCallbacks,
            pending = harness.pendingCallbacks,
            flow = harness.flowCallbacks
        )

        assertTrue(handled)
        assertFalse(harness.pending.active)
        assertEquals("restaurant_booking", harness.openedPlan?.initialSkillId)
        assertNull(harness.openedPlan?.selectedContact)
        assertEquals(
            listOf(
                "blockIdentity:false",
                "reset:open_pending_voice_entry",
                "clearLocalTaskItems",
                "openNew::true:true",
                "clearPending"
            ),
            harness.events
        )
    }

    @Test
    fun invalidPendingVoiceEntryLogsAndClears() {
        val harness = Harness(account = AssistantVoicePermissionAccountState("account-2", true))
        harness.pending = pending(active = true, accountId = "account-1")

        val valid = isAssistantPendingVoiceEntryValid(
            reason = "permission_signal",
            account = harness.accountCallbacks,
            pending = harness.pendingCallbacks
        )

        assertFalse(valid)
        assertFalse(harness.pending.active)
        assertEquals(listOf("dropInvalid:permission_signal:account-1:account-2", "clearPending"), harness.events)
    }

    @Test
    fun rootDelegatesVoiceEntryActionsToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantVoiceEntryActions.kt"
        ).readText(Charsets.UTF_8)
        val rootActions = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantVoiceEntryRootActions.kt"
        ).readText(Charsets.UTF_8)
        val actionGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)
        val postActionShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPostActionShellEffects.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("val voiceEntryRootActions = rootActionGraph.voiceEntry"))
        assertFalse(root.contains("AssistantVoiceEntryRootActions("))
        assertFalse(root.contains("AssistantVoiceEntryRootActionDeps("))
        assertFalse(root.contains("AssistantVoiceEntryRootFlowCallbacks("))
        assertFalse(root.contains("AssistantVoiceEntryRootDispatchCallbacks("))
        assertTrue(actionGraph.contains("AssistantVoiceEntryRootActions("))
        assertTrue(actionGraph.contains("AssistantVoiceEntryRootActionDeps("))
        assertTrue(actionGraph.contains("AssistantVoiceEntryRootFlowCallbacks("))
        assertTrue(actionGraph.contains("AssistantVoiceEntryRootDispatchCallbacks("))
        assertTrue(root.contains("rootActionGraph.startVoiceEntry("))
        assertTrue(root.contains("rootActionGraph.startVoiceInteractionWithPermission("))
        assertFalse(root.contains("voiceEntryRootActions::continueVoiceEntryAfterMicrophoneGranted"))
        assertTrue(postActionShell.contains("voiceEntryRootActions::continueVoiceEntryAfterMicrophoneGranted"))
        assertFalse(root.contains("voiceEntryRootActions.openPendingVoiceEntry()"))
        assertTrue(hostShell.contains("actions.voiceEntry.openPendingVoiceEntry()"))
        assertTrue(hostShell.contains("actions.voiceEntry.continueVoiceEntryAfterIdentityCompleted()"))
        assertTrue(hostShell.contains("actions.voiceEntry.cancelPendingVoiceEntry()"))
        assertFalse(root.contains("AssistantVoiceEntryAccountCallbacks("))
        assertFalse(root.contains("AssistantVoiceEntryPendingCallbacks("))
        assertFalse(root.contains("AssistantVoiceEntryMicrophonePermissionCallbacks("))
        assertFalse(root.contains("AssistantVoiceInteractionDispatchCallbacks("))
        assertFalse(root.contains("ContextCompat.checkSelfPermission("))
        assertFalse(root.contains("startAssistantVoiceEntry("))
        assertFalse(root.contains("startAssistantVoiceInteractionWithPermission("))
        assertFalse(root.contains("continueAssistantVoiceEntryAfterMicrophoneGranted("))
        assertFalse(root.contains("openAssistantPendingVoiceEntry("))
        assertFalse(root.contains("isAssistantPendingVoiceEntryValid("))
        assertFalse(root.contains("fun shouldShowVoiceCloneGuideForPendingEntry("))
        assertFalse(root.contains("taskEntry.pendingVoiceEntryInitialCommand = initialCommand?.trim().orEmpty()"))
        assertFalse(root.contains("taskEntry.singleFlowForceNewVoiceEntryStart = shouldForceNewTaskVoiceEntryStart("))

        assertTrue(action.contains("shouldForceNewTaskVoiceEntryStart("))
        assertTrue(action.lines().size <= 300)
        assertTrue(rootActions.contains("AssistantVoiceEntryAccountCallbacks("))
        assertTrue(rootActions.contains("AssistantVoiceEntryPendingCallbacks("))
        assertTrue(rootActions.contains("AssistantVoiceEntryMicrophonePermissionCallbacks("))
        assertTrue(rootActions.contains("AssistantVoiceInteractionDispatchCallbacks("))
        assertTrue(rootActions.contains("ContextCompat.checkSelfPermission("))
        assertTrue(rootActions.contains("startAssistantVoiceEntry("))
        assertTrue(rootActions.contains("startAssistantVoiceInteractionWithPermission("))
        assertTrue(rootActions.contains("continueAssistantVoiceEntryAfterMicrophoneGranted("))
        assertTrue(rootActions.contains("openAssistantPendingVoiceEntry("))
        assertTrue(rootActions.contains("isAssistantPendingVoiceEntryValid("))
        assertTrue(rootActions.lines().size <= 300)
    }

    private class Harness(
        private val account: AssistantVoicePermissionAccountState = AssistantVoicePermissionAccountState(
            currentAccountId = "account-1",
            mockLoggedIn = true
        ),
        var microphoneGranted: Boolean = true,
        var identityIncomplete: Boolean = false
    ) {
        val events = mutableListOf<String>()
        var pending = pending()
        var interactionPending: AssistantVoiceInteractionPendingState? = null
        var openedPlan: AssistantVoiceEntrySingleFlowPlan? = null

        val accountCallbacks = AssistantVoiceEntryAccountCallbacks(
            accountProvider = { account },
            onSkipUnsignedVoiceInteraction = { events += "skipInteraction:${it.currentAccountId}" },
            onSkipUnsignedVoiceEntry = { events += "skipEntry:${it.currentAccountId}" }
        )
        val permissionCallbacks = AssistantVoiceEntryMicrophonePermissionCallbacks(
            hasMicrophonePermission = { microphoneGranted },
            onMicrophonePermissionGrantedChange = { events += "micGranted:$it" },
            onLaunchVoiceEntryPermission = { events += "launchEntryPermission" },
            onLaunchVoiceInteractionPermission = { events += "launchInteractionPermission" }
        )
        val pendingCallbacks = AssistantVoiceEntryPendingCallbacks(
            pendingProvider = { pending },
            onSavePendingVoiceEntry = { pending = it },
            onClearPendingVoiceEntry = {
                pending = pending(active = false)
                events += "clearPending"
            },
            onDropInvalidPending = {
                events += "dropInvalid:${it.reason}:${it.pendingAccountId}:${it.currentAccountId}"
            },
            onSavePendingVoiceInteraction = { interactionPending = it }
        )
        val flowCallbacks = AssistantVoiceEntryFlowCallbacks(
            onBlockOffline = {
                events += "blockOffline:false"
                false
            },
            onBlockIdentityIncomplete = {
                events += "blockIdentity:$identityIncomplete"
                identityIncomplete
            },
            onResetTaskConversationForNewEntry = { events += "reset:$it" },
            onClearLocalTaskItemsForRequirementEntry = { events += "clearLocalTaskItems" },
            onOpenExistingSingleFlow = { events += "openExisting" },
            onOpenNewSingleFlow = {
                openedPlan = it
                events += "openNew:${it.initialCommand}:${it.startInVoice}:${it.forceNewVoiceEntryStart}"
            }
        )
        val dispatchCallbacks = AssistantVoiceInteractionDispatchCallbacks(
            onToggleVoiceInput = { events += "toggle" },
            onStartNewTaskEntry = { events += "startNew" },
            onApiMicClick = { events += "apiMic" }
        )
    }

    private companion object {
        fun pending(
            initialCommand: String = "",
            startInVoice: Boolean = true,
            resumeExisting: Boolean = false,
            active: Boolean = false,
            accountId: String = "",
            initialSkillId: String? = null,
            selectedContact: SelectedContactTaskContext? = null
        ) = AssistantPendingVoiceEntryState(
            initialCommand = initialCommand,
            startInVoice = startInVoice,
            resumeExisting = resumeExisting,
            active = active,
            accountId = accountId,
            initialSkillId = initialSkillId,
            selectedContact = selectedContact
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
