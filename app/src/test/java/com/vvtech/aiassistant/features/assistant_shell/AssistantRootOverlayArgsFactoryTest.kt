package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import com.vvtech.aiassistant.features.assistant.V88PermissionKind
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootOverlayArgsFactoryTest {
    @Test
    fun factoryBuildsOverlayArgsAndDelegatesPermissionCallbacks() {
        val events = mutableListOf<String>()
        val args = buildAssistantRootOverlayArgs(deps(events))

        assertTrue(args.showBottomTabs)
        assertSame(FinalMainTab.Assistant, args.currentMainTab)
        assertSame(FinalPage.Assistant, args.currentPage)
        assertEquals(V88NetworkMode.Offline, args.networkMode)
        assertEquals(V88PermissionKind.Microphone, args.requestedPermission)
        assertTrue(args.showVoiceModelSheet)

        events.clear()
        args.onNetworkRetry()
        args.onPermissionAllow(V88PermissionKind.Microphone)
        args.onPermissionDeny(V88PermissionKind.Contacts)
        args.onDismissNetworkBlocker()

        assertEquals(
            listOf(
                "message:当前仍为断网模拟，可在开发者功能切换",
                "microphone:true",
                "requested:null",
                "runPending",
                "message:需要通讯录权限才能使用此功能",
                "requested:null",
                "pending:",
                "dismissNetwork"
            ),
            events
        )
    }

    @Test
    fun factoryKeepsGuideAndAccountCallbacksWired() {
        val events = mutableListOf<String>()
        val args = buildAssistantRootOverlayArgs(deps(events))

        events.clear()
        args.onDismissVoiceCloneGuide()
        args.onNeverAskVoiceCloneGuide()
        args.onCloseVoiceModelSheet()
        args.onDismissIdentityOverlay()
        args.onAgentDeviceContactSelectionCancel()

        assertEquals(
            listOf(
                "guideDismiss",
                "guideNever",
                "modelClose",
                "identityDismiss",
                "agentCancel"
            ),
            events
        )
    }

    @Test
    fun rootDelegatesOverlayArgsAssemblyToFactory() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootOverlayArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("buildAssistantRootHostArgs("))
        assertFalse(root.contains("buildAssistantRootOverlayArgs("))
        assertFalse(root.contains("AssistantRootOverlayArgsFactoryDeps("))
        assertTrue(hostShell.contains("buildAssistantRootOverlayArgs("))
        assertTrue(hostShell.contains("AssistantRootOverlayArgsFactoryDeps("))
        assertFalse(root.contains("buildAssistantOverlayArgs("))
        assertFalse(root.contains("AssistantOverlayArgsBuilderInput("))
        assertFalse(root.contains("AssistantOverlayNavigationInput("))
        assertFalse(root.contains("AssistantOverlayPermissionInput("))
        assertFalse(root.contains("AssistantOverlayModelInput("))
        assertFalse(root.contains("AssistantOverlayPermissionActionCallbacks("))
        assertFalse(root.contains("AssistantOverlayModelSelectionCallbacks("))
        assertFalse(root.contains("handleOverlayNetworkRetry("))
        assertFalse(root.contains("handleOverlayPermissionAllow("))
        assertFalse(root.contains("handleOverlayPermissionDeny("))
        assertFalse(root.contains("handleOverlayVoiceModelSelection("))

        assertTrue(factory.contains("buildAssistantOverlayArgs("))
        assertTrue(factory.contains("AssistantOverlayArgsBuilderInput("))
        assertTrue(factory.contains("AssistantOverlayPermissionActionCallbacks("))
        assertTrue(factory.contains("AssistantOverlayModelSelectionCallbacks("))
        assertTrue(factory.contains("handleOverlayNetworkRetry("))
        assertTrue(factory.contains("handleOverlayPermissionAllow("))
        assertTrue(factory.contains("handleOverlayPermissionDeny("))
        assertTrue(factory.contains("handleOverlayVoiceModelSelection("))
        assertTrue(factory.lines().size <= 300)
    }

    private fun deps(events: MutableList<String>): AssistantRootOverlayArgsFactoryDeps =
        AssistantRootOverlayArgsFactoryDeps(
            navigation = AssistantRootOverlayNavigationDeps(
                showBottomTabs = true,
                currentMainTab = FinalMainTab.Assistant,
                onSelectMainTab = { events += "tab:$it" },
                assistantNavHidden = false,
                taskBadgeCount = 2,
                pureVoiceMode = false,
                currentPage = FinalPage.Assistant
            ),
            aiCall = AssistantRootOverlayAiCallDeps(
                selectedRestaurantTitle = "北海渔村",
                activeCallModelTitle = "Qwen3.5",
                assistantUiState = Index9AssistantUiState(),
                aiCallSeconds = 3,
                onAiHangup = { events += "aiHangup" },
                onAiMonitorToggle = { events += "aiMonitor" },
                onAiAudioRouteSelect = { events += "aiRoute:$it" }
            ),
            dial = AssistantRootOverlayDialDeps(
                showCallsDialSheet = true,
                dialInput = "10086",
                translateDialEnabled = false,
                onTranslateDialToggle = { events += "translate:$it" },
                onDialDigit = { events += "digit:$it" },
                onDialDelete = { events += "delete" },
                onDialSheetClose = { events += "dialClose" },
                onDial = { events += "dial" }
            ),
            permission = AssistantRootOverlayPermissionDeps(
                state = AssistantRootOverlayPermissionState(
                    networkMode = V88NetworkMode.Offline,
                    showNetworkBlocker = true,
                    requestedPermission = V88PermissionKind.Microphone
                ),
                callbacks = AssistantRootOverlayPermissionCallbacks(
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
                    onGoHomeAfterContactsDenied = { events += "goHome" },
                    onDismissNetworkBlocker = { events += "dismissNetwork" }
                )
            ),
            guide = AssistantRootOverlayGuideDeps(
                showVoiceCloneGuide = true,
                onStartVoiceCloneGuide = { events += "guideStart" },
                onDismissVoiceCloneGuide = { events += "guideDismiss" },
                onNeverAskVoiceCloneGuide = { events += "guideNever" },
                onApplyTrustedCalleeOverlayArgs = { events += "trusted" }
            ),
            model = AssistantRootOverlayModelDeps(
                state = AssistantRootOverlayModelState(
                    showVoiceModelSheet = true,
                    selectedVoiceModelId = "qwen",
                    availableVoiceModelIds = setOf("QWEN_OMNI_PLUS", "DOUBAO"),
                    voiceModelOptions = emptyList(),
                    realtimeProviderSwitching = false
                ),
                callbacks = AssistantRootOverlayModelCallbacks(
                    onShowMessage = { events += "message:$it" },
                    onShowVoiceModelSheetChange = { events += "modelSheet:$it" },
                    onSwitchRealtimeCallProvider = { events += "switch:$it" },
                    onCloseVoiceModelSheet = { events += "modelClose" }
                )
            ),
            account = AssistantRootOverlayAccountDeps(
                onApplyOtaOverlayArgs = { events += "ota" },
                onApplyLogoutOverlayArgs = { events += "logout" },
                identityOverlaySaving = false,
                identityOverlayError = null,
                identityCompletionOnly = false,
                initialIdentity = null,
                onDismissIdentityOverlay = { events += "identityDismiss" },
                onSkipIdentityForSession = { events += "identitySkip" },
                onSubmitIdentityOverlay = { events += "identitySubmit" },
                onAgentDeviceContactSelectionConfirm = { events += "agentConfirm:${it.size}" },
                onAgentDeviceContactSelectionCancel = { events += "agentCancel" }
            )
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
