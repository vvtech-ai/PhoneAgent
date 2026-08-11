package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import kotlinx.coroutines.flow.MutableStateFlow

internal data class SessionMapperDeps(
    val uiState: MutableStateFlow<Index9AssistantUiState>,
    val handlers: SessionMapperHandlers,
    val taskState: SessionMapperTaskStateAccess,
    val conversationState: SessionMapperConversationStateAccess,
    val detailState: SessionMapperDetailSupplementStateAccess,
    val selectionState: SessionMapperSelectionSuppressionAccess,
    val actions: SessionMapperActions,
    val statusText: SessionMapperStatusText
)

internal data class SessionMapperHandlers(
    val clarificationStepHandler: AssistantSessionClarificationStepHandler,
    val idleResetHandler: AssistantSessionIdleResetHandler,
    val detailSupplementHandler: AssistantSessionDetailSupplementHandler,
    val voicePostApplyHandler: AssistantSessionVoicePostApplyHandler
)

internal data class SessionMapperTaskStateAccess(
    val setTextTaskId: (String?) -> Unit,
    val setVoiceTaskId: (String?) -> Unit,
    val pendingAiCallLaunch: () -> Boolean,
    val setPendingAiCallLaunch: (Boolean) -> Unit,
    val setPendingFreshTask: (Boolean) -> Unit,
    val activeInteractionChannel: () -> InteractionChannel,
    val setActiveInteractionChannel: (InteractionChannel) -> Unit
)

internal data class SessionMapperConversationStateAccess(
    val pendingSelectionContinuation: () -> AssistantSessionPendingSelectionContinuation?,
    val setPendingSelectionContinuation: (AssistantSessionPendingSelectionContinuation?) -> Unit,
    val clearActiveDialogContext: () -> Unit,
    val setPrimarySummaryAction: (AssistantActionChip?) -> Unit,
    val latestCallPageSeed: () -> CallPageData,
    val setLatestCallPageSeed: (CallPageData) -> Unit,
    val lastCommittedUserTranscript: () -> String?
)

internal data class SessionMapperDetailSupplementStateAccess(
    val contactTaskId: () -> String?,
    val contactValue: () -> String?,
    val detailTaskId: () -> String?,
    val detailValue: () -> String?,
    val completedTaskId: () -> String?
)

internal data class SessionMapperSelectionSuppressionAccess(
    val consumedTaskId: () -> String?,
    val consumedSignature: () -> String?,
    val setConsumedTaskId: (String?) -> Unit,
    val setConsumedSignature: (String?) -> Unit
)

internal data class SessionMapperActions(
    val refreshHistory: () -> Unit,
    val stopVoiceInteraction: (String) -> Unit,
    val log: (String) -> Unit
)

internal data class SessionMapperStatusText(
    val currentLanguage: () -> VoiceLanguage,
    val taskReadyStatus: () -> String,
    val contactLabel: () -> String,
    val detailLabel: () -> String
)
