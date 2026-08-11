package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import com.vvtech.aiassistant.callengine.AssistantCallEngineEvent
import com.vvtech.aiassistant.callengine.AssistantCallEngineGateway
import com.vvtech.aiassistant.callengine.AssistantCallMode
import com.vvtech.aiassistant.callengine.AssistantCallRequest
import com.vvtech.aiassistant.callengine.AssistantClientCallController
import com.vvtech.aiassistant.features.assistant_calls.AssistantDialerPreferenceState
import com.vvtech.aiassistant.features.assistant_calls.AssistantDialerStateHolder
import com.vvtech.aiassistant.features.assistant_calls.DialRecentCallKind
import com.vvtech.aiassistant.features.assistant_calls.DialTargetSelection
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallLaunchInput
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallLaunchResult
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootCallEntryActionsTest {
    @Test
    fun rootDelegatesCallEntryActionsToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootCallEntryActions.kt"
        ).readText(Charsets.UTF_8)
        val actionGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt"
        ).readText(Charsets.UTF_8)
        val mainFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val assistantFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt"
        ).readText(Charsets.UTF_8)
        val hostShell = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText(Charsets.UTF_8)
        val dialFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootOverlayDialDepsFactory.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(root.contains("val callEntryActions = rootActionGraph.callEntry"))
        assertFalse(root.contains("AssistantRootCallEntryActions("))
        assertFalse(root.contains("AssistantRootCallEntryActionDeps("))
        assertTrue(actionGraph.contains("AssistantRootCallEntryActions("))
        assertTrue(actionGraph.contains("AssistantRootCallEntryActionDeps("))
        assertTrue(assistantFactory.contains("actions.callEntry.openCallsDialSheet(selectTranslate = true)"))
        assertTrue(action.contains("TranslationCallLaunchInput("))
        assertTrue(mainFactory.contains("actions.callEntry::openDialFromContact"))
        assertTrue(hostShell.contains("actions.callEntry::runPendingPermissionAction"))
        assertTrue(dialFactory.contains("onDial = actions.callEntry::runDialSheetAction"))

        assertFalse(root.contains("fun openCallsDialSheet("))
        assertFalse(root.contains("fun startRealtimeTranslationCallFromDial("))
        assertFalse(root.contains("fun unlockDeveloperModeFromDial("))
        assertFalse(root.contains("fun runNormalCallFromDial("))
        assertFalse(root.contains("fun runNormalCallFromContact("))
        assertFalse(root.contains("fun runPendingV88PermissionAction("))
        assertFalse(root.contains("runAssistantSystemPhoneCallFromDial("))
        assertFalse(root.contains("runAssistantSystemPhoneCallFromContact("))
        assertFalse(root.contains("runAssistantPendingPermissionAction("))
        assertFalse(root.contains("AssistantPendingPermissionActionCallbacks("))
        assertFalse(root.contains("FinalDeveloperModeUnlockCode"))
        assertFalse(root.contains("normalizeDialNumber(callDialState.dialInput)"))

        assertFalse(action.contains("runAssistantSystemPhoneCallFromDial("))
        assertFalse(action.contains("runAssistantSystemPhoneCallFromContact("))
        assertTrue(action.contains("clientCallController.start("))
        assertTrue(action.contains("runAssistantPendingPermissionAction("))
        assertTrue(action.contains("AssistantPendingPermissionActionCallbacks("))
        assertTrue(action.contains("FinalDeveloperModeUnlockCode"))
        assertTrue(action.lines().size <= 300)
    }

    @Test
    fun openCallsDialSheetKeepsCurrentTabAndClosesComposer() {
        val harness = Harness()

        harness.actions.openCallsDialSheet(selectTranslate = true)

        assertTrue(harness.callDialState.showCallsDialSheet)
        assertTrue(harness.callDialState.dialer.translateEnabled)
        assertFalse(harness.events.contains("callsTab"))
        assertTrue(harness.events.contains("closeComposer"))
    }

    @Test
    fun pendingPermissionUploadAttachmentMarksTaskEntry() {
        val harness = Harness()
        harness.permissionOverlayState.pendingPermissionAction = "upload_attachment"

        assertTrue(harness.actions.runPendingPermissionAction())

        assertTrue(harness.taskEntry.confirmAttachmentUploaded)
        assertFalse(harness.permissionOverlayState.pendingPermissionAction.isNotEmpty())
    }

    @Test
    fun dialSheetActionUsesRegionAwareLauncherWhenTranslationIsEnabled() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = true
        harness.callDialState.dialer.dialInput = "13800138000"

        harness.actions.runDialSheetAction()

        assertTrue(harness.events.contains("translation"))
        assertTrue(harness.requests.isEmpty())
        assertEquals("21311780", harness.translationRequests.single().domesticSipAccountId)
        assertEquals("1008", harness.translationRequests.single().internationalSipAccountId)
    }

    @Test
    fun normalDialOpensSystemDialerWithoutSipOrAudioPermission() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = false
        harness.callDialState.dialer.dialInput = "13800138000"

        harness.actions.runDialSheetAction()

        assertEquals(listOf("systemDial:+8613800138000"), harness.events)
        assertTrue(harness.translationRequests.isEmpty())
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun normalDialAllowsChinaLandlineToReachSystemDialer() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = false
        harness.callDialState.dialer.dialInput = "01088886666"

        harness.actions.runDialSheetAction()

        assertEquals(listOf("systemDial:+861088886666"), harness.events)
        assertTrue(harness.translationRequests.isEmpty())
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun emptyNormalDialDoesNotOpenSystemDialerWithCountryCodeOnly() {
        val harness = Harness()

        harness.actions.runDialSheetAction()

        assertTrue(harness.events.isEmpty())
        assertTrue(harness.translationRequests.isEmpty())
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun contactDetailCallOpensSystemDialerDirectlyWithoutOpeningDialSheet() {
        val harness = Harness(
            selectedContactPhone = "+81 90-1234-5678",
            selectedContactName = "田中"
        )

        assertTrue(harness.actions.openDialFromContact())

        assertEquals(listOf("systemDial:+81 90-1234-5678"), harness.events)
        assertFalse(harness.callDialState.showCallsDialSheet)
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun contactDetailChinaLandlineKeepsLocalSystemDialTarget() {
        val harness = Harness(
            selectedContactPhone = "010-8888-6666",
            selectedContactName = "前台"
        )

        assertTrue(harness.actions.openDialFromContact())

        assertEquals(listOf("systemDial:010-8888-6666"), harness.events)
        assertFalse(harness.callDialState.showCallsDialSheet)
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun contactDetailChinaMobileKeepsLocalSystemDialTarget() {
        val harness = Harness(
            selectedContactPhone = "13800138000",
            selectedContactName = "张三"
        )

        assertTrue(harness.actions.openDialFromContact())

        assertEquals(listOf("systemDial:13800138000"), harness.events)
        assertFalse(harness.callDialState.showCallsDialSheet)
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun invalidChinaMobileStopsBeforePermissionAndSipSideEffects() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = false
        harness.callDialState.dialer.dialInput = "159158743619"

        harness.actions.runDialSheetAction()

        assertEquals(listOf("message:请输入正确的手机号码"), harness.events)
        assertTrue(harness.requests.isEmpty())
        assertTrue(harness.translationRequests.isEmpty())
    }

    @Test
    fun translationDialAllowsChinaLandlineAndKeepsRawNumberForRouting() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = true
        harness.callDialState.dialer.dialInput = "01088886666转123"

        harness.actions.runDialSheetAction()

        assertEquals(listOf("offlineCheck", "microphoneCheck", "translation"), harness.events)
        assertEquals("01088886666转123", harness.translationRequests.single().rawNumber)
    }

    @Test
    fun translationDialAllowsChinaServiceNumber() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = true
        harness.callDialState.dialer.dialInput = "4008001234"

        harness.actions.runDialSheetAction()

        assertTrue(harness.events.contains("translation"))
        assertEquals("4008001234", harness.translationRequests.single().rawNumber)
    }

    @Test
    fun emergencyNumberAlwaysUsesSystemDialerEvenWhenTranslationIsEnabled() {
        val harness = Harness()
        harness.callDialState.dialer.translateEnabled = true
        harness.callDialState.dialer.dialInput = "110"

        harness.actions.runDialSheetAction()

        assertEquals(listOf("systemDial:110"), harness.events)
        assertTrue(harness.translationRequests.isEmpty())
        assertTrue(harness.requests.isEmpty())
    }

    @Test
    fun ordinarySystemHistoryKeepsRawNumberWhenDialed() {
        val harness = Harness()

        assertTrue(
            harness.actions.runHistoryCall(
                DialTargetSelection(
                    phoneNumber = "010-8888-6666",
                    displayName = "前台",
                    callKind = DialRecentCallKind.NORMAL
                )
            )
        )

        assertEquals(listOf("systemDial:010-8888-6666"), harness.events)
        assertTrue(harness.translationRequests.isEmpty())
    }

    @Test
    fun translationHistoryCallKeepsCurrentToggleAndUsesTranslationChain() {
        val harness = Harness()

        assertTrue(
            harness.actions.runHistoryCall(
                DialTargetSelection(
                    phoneNumber = "+861088886666",
                    displayName = "前台",
                    callKind = DialRecentCallKind.TRANSLATION,
                    countryIso = "CN"
                )
            )
        )

        assertFalse(harness.callDialState.dialer.translateEnabled)
        assertTrue(harness.events.contains("translation"))
        assertEquals("01088886666", harness.translationRequests.single().rawNumber)
    }

    @Test
    fun callRecordRedialKeepsExistingClientSipPath() {
        val harness = Harness()

        assertTrue(harness.actions.runNormalCallToNumber("+8613800138000"))

        assertEquals(
            listOf("offlineCheck", "microphoneCheck", "clientSip:NORMAL"),
            harness.events
        )
        assertTrue(harness.translationRequests.isEmpty())
        assertEquals("+8613800138000", harness.requests.single().phoneNumber)
    }

    private class Harness(
        selectedContactPhone: String = "",
        selectedContactName: String = ""
    ) {
        val events = mutableListOf<String>()
        val callDialState = callDialState()
        val permissionOverlayState = permissionOverlayState()
        val taskEntry = taskEntryState()
        val requests = mutableListOf<AssistantCallRequest>()
        val translationRequests = mutableListOf<TranslationCallLaunchInput>()
        private val gateway = object : AssistantCallEngineGateway {
            override fun start(
                request: AssistantCallRequest,
                onEvent: (AssistantCallEngineEvent) -> Unit
            ) {
                requests += request
                events += "clientSip:${request.mode.name}"
            }

            override fun setMuted(muted: Boolean) = Unit
            override fun setSpeakerEnabled(enabled: Boolean) = Unit
            override fun sendDtmf(digit: Char) = Unit
            override fun hangup() = Unit
            override fun release() = Unit
        }
        val actions = AssistantRootCallEntryActions(
            AssistantRootCallEntryActionDeps(
                callDialState = callDialState,
                clientCallController = AssistantClientCallController(gateway, onTerminal = {}),
                onStartTranslationCall = { request ->
                    translationRequests += request
                    events += "translation"
                    TranslationCallLaunchResult.Started
                },
                permissionOverlayState = permissionOverlayState,
                taskEntry = taskEntry,
                selectedContactSystemDialPhoneProvider = { selectedContactPhone },
                selectedContactNameProvider = { selectedContactName },
                onLaunchSystemDialer = {
                    events += "systemDial:$it"
                    true
                },
                translationProviderProvider = { "QWEN_OMNI_PLUS" },
                selectedDomesticSipAccountIdProvider = { "21311780" },
                selectedInternationalSipAccountIdProvider = { "1008" },
                onBlockOffline = {
                    events += "offlineCheck"
                    false
                },
                onHasMicrophonePermissionForVoiceEntry = {
                    events += "microphoneCheck"
                    true
                },
                onLaunchTranslationAudioPermission = {},
                onEnableDeveloperMode = { events += "enableDeveloper" },
                onShowDeveloperModeUnlocked = { events += "developerToast" },
                onApplyCallsMainTab = { events += "callsTab" },
                onCloseHomeComposer = { events += "closeComposer" },
                onShowMessage = { events += "message:$it" }
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

        fun callDialState(): AssistantCallDialState = AssistantCallDialState(
            dialer = AssistantDialerStateHolder(
                preferences = AssistantDialerPreferenceState(
                    translateEnabledState = mutableStateOf(false)
                ),
                dialInputState = mutableStateOf(""),
                lastDialedNumberState = mutableStateOf("")
            ),
            showCallsDialSheetState = mutableStateOf(false),
            normalCallReturnPageState = mutableStateOf("Calls"),
            normalCallMutedState = mutableStateOf(false),
            normalCallSpeakerState = mutableStateOf(true),
            normalCallSecondsState = mutableStateOf(0)
        )

        fun permissionOverlayState(): AssistantPermissionOverlayState = AssistantPermissionOverlayState(
            networkModeNameState = mutableStateOf("Normal"),
            showNetworkBlockerState = mutableStateOf(false),
            requestedPermissionNameState = mutableStateOf(null),
            pendingPermissionActionState = mutableStateOf(""),
            microphonePermissionGrantedState = mutableStateOf(false),
            storagePermissionGrantedState = mutableStateOf(false),
            contactsPermissionGrantedState = mutableStateOf(false),
            phonePermissionGrantedState = mutableStateOf(false)
        )

        fun taskEntryState(): AssistantTaskEntryState = AssistantTaskEntryState(
            taskStarted = mutableStateOf(false),
            taskUserText = mutableStateOf(""),
            taskTextDraft = mutableStateOf(""),
            aiThinking = mutableStateOf(false),
            aiReplyVisible = mutableStateOf(false),
            singleFlowInitialCommand = mutableStateOf(""),
            singleFlowSelectedContact = mutableStateOf(null),
            singleFlowStartInVoice = mutableStateOf(false),
            singleFlowResumeListeningOnly = mutableStateOf(false),
            singleFlowForceNewVoiceEntryStart = mutableStateOf(false),
            singleFlowEntryKey = mutableStateOf(0L),
            pendingVoiceEntryInitialCommand = mutableStateOf(""),
            pendingVoiceEntryStartInVoice = mutableStateOf(true),
            pendingVoiceEntryResumeExisting = mutableStateOf(false),
            pendingVoiceEntryActive = mutableStateOf(false),
            pendingVoiceEntryAccountId = mutableStateOf(""),
            pendingVoiceInteractionPermissionActive = mutableStateOf(false),
            pendingVoiceInteractionAccountId = mutableStateOf(""),
            pendingVoiceInteractionForceNewTaskEntry = mutableStateOf(false),
            pendingVoiceInteractionUseToggle = mutableStateOf(false),
            voiceEntryPermissionGrantedSignal = mutableStateOf(0L),
            selectedRestaurantId = mutableStateOf(null),
            restaurantConfirmed = mutableStateOf(false),
            confirmingRestaurantId = mutableStateOf(null),
            selectedFallbackIds = mutableStateListOf(),
            requiredFallbackIds = mutableStateListOf(),
            fallbackConfirmed = mutableStateOf(false),
            confirmingFallbackId = mutableStateOf(null),
            confirmAttachmentUploaded = mutableStateOf(false),
            aiCallSeconds = mutableStateOf(0)
        )
    }
}
