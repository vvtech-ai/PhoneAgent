package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.isTopLevel

internal class AssistantPageHostDerivedStateInput(
    val currentPage: FinalPage,
    val assistantUiState: Index9AssistantUiState,
    val localTaskStarted: Boolean,
    val localTaskUserText: String,
    val localAiThinking: Boolean,
    val localAiReplyVisible: Boolean,
    val useSingleFlowConversation: Boolean,
    val resultCallIdFallback: String?,
    val singleFlowTransitionContentVisible: Boolean = false
)

internal class AssistantPageHostDerivedState(
    val showBottomTabs: Boolean,
    val assistantNavHidden: Boolean,
    val pageBottomInset: Dp,
    val effectiveTaskStarted: Boolean,
    val effectiveTaskUserText: String,
    val effectiveAiThinking: Boolean,
    val effectiveAiReplyVisible: Boolean,
    val resultCallId: String
)

internal fun deriveAssistantPageHostState(
    input: AssistantPageHostDerivedStateInput
): AssistantPageHostDerivedState {
    val assistantUiState = input.assistantUiState
    val backendTaskVisible = assistantUiState.clarificationSteps.isNotEmpty() ||
        assistantUiState.selectionSheet != null ||
        assistantUiState.summary != null ||
        assistantUiState.detailSupplement != null ||
        assistantUiState.processingTurn ||
        assistantUiState.taskId != null
    val backendUserText = assistantUiState.clarificationSteps
        .lastOrNull { it.role == VoiceRole.User }
        ?.text
    val backendAssistantVisible = assistantUiState.clarificationSteps.any { it.role == VoiceRole.Assistant } ||
        assistantUiState.selectionSheet != null ||
        assistantUiState.summary != null ||
        assistantUiState.detailSupplement != null ||
        !assistantUiState.error.isNullOrBlank()
    val assistantNavHidden = false

    return AssistantPageHostDerivedState(
        showBottomTabs = input.currentPage.isTopLevel() &&
            !input.singleFlowTransitionContentVisible,
        assistantNavHidden = assistantNavHidden,
        pageBottomInset = 0.dp,
        effectiveTaskStarted = if (input.useSingleFlowConversation) {
            input.localTaskStarted
        } else {
            input.localTaskStarted || backendTaskVisible
        },
        effectiveTaskUserText = backendUserText ?: input.localTaskUserText,
        effectiveAiThinking = input.localAiThinking || assistantUiState.processingTurn || assistantUiState.loading,
        effectiveAiReplyVisible = input.localAiReplyVisible || backendAssistantVisible,
        resultCallId = assistantUiState.currentCallId.orEmpty().ifBlank {
            input.resultCallIdFallback.orEmpty()
        }
    )
}
