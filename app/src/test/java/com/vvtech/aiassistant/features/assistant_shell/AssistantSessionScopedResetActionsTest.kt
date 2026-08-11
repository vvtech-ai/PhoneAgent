package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionScopedResetActionsTest {
    @Test
    fun resetSessionScopedUiStateKeepsLegacyOrderAndReasons() {
        val events = mutableListOf<String>()

        resetAssistantSessionScopedUiState(
            reason = "account_changed",
            activeAccountId = "account-1",
            log = AssistantSessionScopedResetLogCallbacks { input ->
                events += "log:${input.reason}:${input.activeAccountId}"
            },
            primary = AssistantSessionScopedPrimaryResetCallbacks(
                onResetTaskConversationForNewEntry = { events += "resetTask:$it" },
                onResetTranslationRuntime = { events += "resetTranslation:$it" },
                onClearLocalTaskItemsForRequirementEntry = { events += "clearLocalTaskItems" },
                onClearPendingVoiceEntryState = { events += "clearPendingVoiceEntry" }
            ),
            ui = AssistantSessionScopedUiResetCallbacks(
                onClearAgentRequests = { events += "clearAgentRequests" },
                onClearRequestedPermission = { events += "clearRequestedPermission" },
                onClearSystemPhonePending = { events += "clearSystemPhonePending" },
                onClearIdentityOverlayError = { events += "clearIdentityOverlayError" },
                onSetIdentityInitOverlayVisible = { events += "setIdentityInitOverlayVisible:$it" },
                onDismissNetworkBlocker = { events += "dismissNetworkBlocker" },
                onHideDialSheet = { events += "hideDialSheet" },
                onClearSessionScopedUiFlags = { events += "clearSessionScopedUiFlags" },
                onHideVoiceModelSheet = { events += "hideVoiceModelSheet" },
                onCloseHomeComposer = { events += "closeHomeComposer" },
                onGoHome = { events += "goHome" }
            )
        )

        assertEquals(
            listOf(
                "log:account_changed:account-1",
                "resetTask:account_boundary_account_changed",
                "resetTranslation:account_changed",
                "clearLocalTaskItems",
                "clearPendingVoiceEntry",
                "clearAgentRequests",
                "clearRequestedPermission",
                "clearSystemPhonePending",
                "clearIdentityOverlayError",
                "setIdentityInitOverlayVisible:false",
                "dismissNetworkBlocker",
                "hideDialSheet",
                "clearSessionScopedUiFlags",
                "hideVoiceModelSheet",
                "closeHomeComposer",
                "goHome"
            ),
            events
        )
    }

    @Test
    fun authResetSessionCallbackFactoryKeepsLegacyOrderAndLogMessage() {
        val events = mutableListOf<String>()

        val callback = buildAssistantRootAuthResetSessionCallback(
            AssistantRootAuthResetSessionCallbackDeps(
                activeAccountIdProvider = { "account-2" },
                log = { events += "log:$it" },
                onResetTaskConversationForNewEntry = { events += "resetTask:$it" },
                onResetTranslationRuntime = { events += "resetTranslation:$it" },
                onClearLocalTaskItemsForRequirementEntry = { events += "clearLocalTaskItems" },
                onClearPendingVoiceEntryState = { events += "clearPendingVoiceEntry" },
                onClearAgentRequests = { events += "clearAgentRequests" },
                onClearRequestedPermission = { events += "clearRequestedPermission" },
                onClearSystemPhonePending = { events += "clearSystemPhonePending" },
                onClearIdentityOverlayError = { events += "clearIdentityOverlayError" },
                onSetIdentityInitOverlayVisible = { events += "setIdentityInitOverlayVisible:$it" },
                onDismissNetworkBlocker = { events += "dismissNetworkBlocker" },
                onHideDialSheet = { events += "hideDialSheet" },
                onClearSessionScopedUiFlags = { events += "clearSessionScopedUiFlags" },
                onHideVoiceModelSheet = { events += "hideVoiceModelSheet" },
                onCloseHomeComposer = { events += "closeHomeComposer" },
                onGoHome = { events += "goHome" }
            )
        )

        callback("login_changed")

        assertEquals(
            listOf(
                "log:reset session scoped ui reason=login_changed activeAccountId=account-2",
                "resetTask:account_boundary_login_changed",
                "resetTranslation:login_changed",
                "clearLocalTaskItems",
                "clearPendingVoiceEntry",
                "clearAgentRequests",
                "clearRequestedPermission",
                "clearSystemPhonePending",
                "clearIdentityOverlayError",
                "setIdentityInitOverlayVisible:false",
                "dismissNetworkBlocker",
                "hideDialSheet",
                "clearSessionScopedUiFlags",
                "hideVoiceModelSheet",
                "closeHomeComposer",
                "goHome"
            ),
            events
        )
    }

    @Test
    fun rootDelegatesSessionScopedResetToShellAction() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantSessionScopedResetActions.kt"
        ).readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootAuthResetSessionCallbackFactory.kt"
        ).readText(Charsets.UTF_8)
        val binder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootAuthResetCallbackBinder.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("bindAssistantRootAuthResetSessionCallback("))
        assertTrue(root.contains("AssistantRootAuthResetCallbackBindingArgs("))
        assertFalse(root.contains("buildAssistantRootAuthResetSessionCallback("))
        assertFalse(root.contains("AssistantRootAuthResetSessionCallbackDeps("))
        assertFalse(root.contains("resetAssistantSessionScopedUiState("))
        assertFalse(root.contains("AssistantSessionScopedPrimaryResetCallbacks("))
        assertFalse(root.contains("AssistantSessionScopedUiResetCallbacks("))
        assertFalse(root.contains("fun resetSessionScopedUiState("))
        assertFalse(root.contains("assistantViewModel.resetTaskConversationForNewEntry(\"account_boundary_\$"))
        assertFalse(root.contains("transientOverlayState.clearAgentRequests()"))

        assertTrue(action.contains("account_boundary_\$reason"))
        assertTrue(binder.contains("buildAssistantRootAuthResetSessionCallback("))
        assertTrue(binder.contains("AssistantRootAuthResetSessionCallbackDeps("))
        assertTrue(binder.contains("authResetSessionCallback[0]"))
        assertTrue(binder.contains("clearAssistantRootLocalTaskItemsForRequirementEntry(args.taskEntry)"))
        assertTrue(binder.contains("clearAssistantRootPendingVoiceEntryState(rootRuntimeGraph, args.taskEntry)"))
        assertTrue(factory.contains("resetAssistantSessionScopedUiState("))
        assertTrue(factory.contains("AssistantSessionScopedPrimaryResetCallbacks("))
        assertTrue(factory.contains("AssistantSessionScopedUiResetCallbacks("))
        assertTrue(factory.contains("activeAccountIdProvider()"))
        assertTrue(action.lines().size <= 300)
        assertTrue(binder.lines().size <= 120)
        assertTrue(factory.lines().size <= 120)
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
