package com.vvtech.aiassistant.features.assistant

internal class AssistantConversationArgsBuilderInput(
    val core: AssistantConversationCoreInput,
    val callbacks: AssistantConversationCallbacksInput,
    val agent: AssistantConversationAgentInput,
    val notification: AssistantConversationNotificationInput,
    val singleFlow: AssistantConversationSingleFlowInput
)

internal class AssistantConversationCoreInput(
    val assistantViewModel: AssistantViewModel,
    val assistantUiState: Index9AssistantUiState,
    val homeComposerOpen: Boolean,
    val effectiveTaskStarted: Boolean,
    val effectiveTaskUserText: String,
    val effectiveAiThinking: Boolean,
    val effectiveAiReplyVisible: Boolean,
    val taskTextDraft: String,
    val pureVoiceMode: Boolean,
    val pureVoicePrecheck: com.vvtech.aiassistant.features.assistant_pure_voice.PureVoicePrecheckUiState?,
    val composerMode: String
)

internal class AssistantConversationCallbacksInput(
    val onHomeComposerOpenChange: (Boolean) -> Unit,
    val onTaskTextDraftChange: (String) -> Unit,
    val onComposerModeChange: (String) -> Unit,
    val onQuickVoiceEntry: (String?) -> Boolean,
    val onOpenTranslateDial: () -> Unit,
    val onBlockHomeCardIfOffline: () -> Boolean,
    val activeCallModelTitle: String,
    val onOpenCallModelSheet: () -> Unit,
    val onStartVoice: () -> Unit,
    val onStopVoice: () -> Unit,
    val onInterruptTts: () -> Unit,
    val onSendText: () -> Unit,
    val onStopTask: () -> Unit,
    val onPersistTaskContactIfNeeded: (EffectiveTaskContact) -> EffectiveTaskContact
)

internal class AssistantConversationAgentInput(
    val onAgentDocumentSelect: () -> Unit,
    val onAgentDocumentCancel: () -> Unit,
    val onAgentSheetDismiss: () -> Unit,
    val onReplayTts: (String) -> Unit
)

internal class AssistantConversationNotificationInput(
    val homeNotificationVisible: Boolean,
    val homeNotificationText: String,
    val homeNotificationExtra: String,
    val homeNotificationStatusKind: FinalTaskStatusKind,
    val onClickHomeNotification: () -> Unit,
    val onDismissHomeNotification: () -> Unit
)

internal class AssistantConversationSingleFlowInput(
    val singleFlowInitialCommand: String,
    val onConsumeSingleFlowSelectedContact: () -> com.vvtech.aiassistant.core.model.SelectedContactTaskContext?,
    val singleFlowStartInVoice: Boolean,
    val singleFlowResumeListeningOnly: Boolean,
    val singleFlowEntryKey: Long,
    val singleFlowForceNewVoiceEntryStart: Boolean,
    val onStartVoiceInteractionWithPermission: (forceNewTaskEntry: Boolean, useToggle: Boolean) -> Unit
)

internal fun buildAssistantConversationArgs(
    input: AssistantConversationArgsBuilderInput
): AssistantPageArgs = AssistantPageArgs().also { args ->
    with(input.core) {
        args.assistantViewModel = assistantViewModel
        args.assistantUiState = assistantUiState
        args.homeComposerOpen = homeComposerOpen
        args.effectiveTaskStarted = effectiveTaskStarted
        args.effectiveTaskUserText = effectiveTaskUserText
        args.effectiveAiThinking = effectiveAiThinking
        args.effectiveAiReplyVisible = effectiveAiReplyVisible
        args.taskTextDraft = taskTextDraft
        args.pureVoiceMode = pureVoiceMode
        args.pureVoicePrecheck = pureVoicePrecheck
        args.composerMode = composerMode
    }
    with(input.callbacks) {
        args.onHomeComposerOpenChange = onHomeComposerOpenChange
        args.onTaskTextDraftChange = onTaskTextDraftChange
        args.onComposerModeChange = onComposerModeChange
        args.onQuickVoiceEntry = onQuickVoiceEntry
        args.onOpenTranslateDial = onOpenTranslateDial
        args.onBlockHomeCardIfOffline = onBlockHomeCardIfOffline
        args.activeCallModelTitle = activeCallModelTitle
        args.onOpenCallModelSheet = onOpenCallModelSheet
        args.onStartVoice = onStartVoice
        args.onStopVoice = onStopVoice
        args.onInterruptTts = onInterruptTts
        args.onSendText = onSendText
        args.onStopTask = onStopTask
        args.onPersistTaskContactIfNeeded = onPersistTaskContactIfNeeded
    }
    with(input.agent) {
        args.onAgentDocumentSelect = onAgentDocumentSelect
        args.onAgentDocumentCancel = onAgentDocumentCancel
        args.onAgentSheetDismiss = onAgentSheetDismiss
        args.onReplayTts = onReplayTts
    }
    with(input.notification) {
        args.homeNotificationVisible = homeNotificationVisible
        args.homeNotificationText = homeNotificationText
        args.homeNotificationExtra = homeNotificationExtra
        args.homeNotificationStatusKind = homeNotificationStatusKind
        args.onClickHomeNotification = onClickHomeNotification
        args.onDismissHomeNotification = onDismissHomeNotification
    }
    with(input.singleFlow) {
        args.singleFlowInitialCommand = singleFlowInitialCommand
        args.onConsumeSingleFlowSelectedContact = onConsumeSingleFlowSelectedContact
        args.singleFlowStartInVoice = singleFlowStartInVoice
        args.singleFlowResumeListeningOnly = singleFlowResumeListeningOnly
        args.singleFlowEntryKey = singleFlowEntryKey
        args.singleFlowForceNewVoiceEntryStart = singleFlowForceNewVoiceEntryStart
        args.onStartVoiceInteractionWithPermission = onStartVoiceInteractionWithPermission
    }
}
