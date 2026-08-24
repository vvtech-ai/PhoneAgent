package com.vvtech.aiassistant.features.assistant_actions

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.localizedConfirmingSelectionOptionStatus
import com.vvtech.aiassistant.features.assistant.localizedSelectionOptionConfirmFailureError
import com.vvtech.aiassistant.features.assistant.localizedSelectionOptionConfirmFailureStatus
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionPendingSelectionContinuation
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionSelectionSheetPolicy
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class AssistantUserDecisionActionHandler(
    private val viewModel: AssistantViewModel
) {
    fun onSelectSelectionOption(option: SelectionSheetOption) {
        val uiState = viewModel.internalUiState
        val previousSheet = uiState.value.selectionSheet
        val previousConsumedTaskId = viewModel.consumedSelectionSheetTaskId
        val previousConsumedSignature = viewModel.consumedSelectionSheetSignature
        val previousPendingSelectionContinuation = viewModel.pendingSelectionContinuation
        viewModel.consumedSelectionSheetTaskId = uiState.value.taskId
        viewModel.consumedSelectionSheetSignature = previousSheet?.let(AssistantSessionSelectionSheetPolicy::signature)
        viewModel.pendingSelectionContinuation = AssistantSessionPendingSelectionContinuation(
            sceneType = uiState.value.sceneType,
            targetName = option.title
        )
        viewModel.autoResumeListeningJob?.cancel()
        viewModel.pendingSpeechTurn?.cancel()
        viewModel.queuedRecognizedTurns.clear()
        viewModel.pendingStructuredRecognizedTurn = null
        viewModel.latestRealtimeAssistantReplyForBackend = null
        if (viewModel.activeInteractionChannel == InteractionChannel.VOICE) {
            viewModel.stopVoiceInteraction()
        }
        uiState.update {
            it.copy(
                listening = false,
                processingTurn = true,
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                selectionSheet = null,
                error = null,
                status = viewModel.localizedConfirmingSelectionOptionStatus(option.title)
            )
        }
        viewModel.viewModelScope.launch {
            runCatching {
                viewModel.sendActionThroughActiveChannel(option.actionId, option.actionLabel)
            }.onSuccess { response ->
                viewModel.applyChannelSession(response)
                viewModel.refreshHistory()
            }.onFailure { throwable ->
                viewModel.consumedSelectionSheetTaskId = previousConsumedTaskId
                viewModel.consumedSelectionSheetSignature = previousConsumedSignature
                viewModel.pendingSelectionContinuation = previousPendingSelectionContinuation
                uiState.update {
                    it.copy(
                        processingTurn = false,
                        error = throwable.message
                            ?: viewModel.localizedSelectionOptionConfirmFailureError(),
                        selectionSheet = previousSheet,
                        status = throwable.message
                            ?: viewModel.localizedSelectionOptionConfirmFailureStatus()
                    )
                }
            }
        }
    }

    fun onConfirm() {
        val action = viewModel.primarySummaryAction ?: return
        val uiState = viewModel.internalUiState
        val opensCallPage = action.actionId.contains("execute")
        if (opensCallPage) {
            viewModel.pendingAiCallLaunch = true
            if (viewModel.activeInteractionChannel == InteractionChannel.VOICE) {
                viewModel.voiceDuplexCoordinator.suspendDialogAudioForCall("summary_confirm_call")
            }
            val callSeed = viewModel.latestCallPageSeed.copy(
                status = currentAppText("正在发起电话...", "Starting call..."),
                transcript = viewModel.latestCallPageSeed.transcript + TranscriptLine(
                    role = TranscriptRole.Note,
                    text = "Backend outbound call has started with the current confirmed details."
                )
            )
            uiState.update {
                it.copy(
                    showAiCallPage = true,
                    callUiMode = CallUiMode.Ai,
                    currentCallId = null,
                    callPageData = callSeed
                )
            }
            viewModel.voiceDuplexCoordinator.suspendDialogAudioForCall("summary_confirm_call_page_visible")
            viewModel.startCallSessionPolling()
        }

        viewModel.viewModelScope.launch {
            uiState.update {
                it.copy(
                    processingTurn = true,
                    status = if (opensCallPage) {
                        currentAppText("正在外呼...", "Calling...")
                    } else {
                        currentAppText("正在继续处理...", "Continuing...")
                    }
                )
            }
            runCatching {
                viewModel.sendActionThroughActiveChannel(action.actionId, action.label)
            }.onSuccess { response ->
                viewModel.applyChannelSession(response)
                viewModel.refreshHistory()
                if (opensCallPage) {
                    response.messages.lastOrNull { it.resultSummary != null }
                        ?.resultSummary
                        ?.let(viewModel::appendCallResult)
                }
            }.onFailure { throwable ->
                viewModel.pendingAiCallLaunch = false
                uiState.update {
                    it.copy(
                        processingTurn = false,
                        error = throwable.message ?: currentAppText("操作执行失败", "Failed to perform action"),
                        status = if (opensCallPage) {
                            currentAppText("外呼失败", "Outbound call failed")
                        } else {
                            currentAppText("处理失败", "Processing failed")
                        }
                    )
                }
                if (opensCallPage) {
                    viewModel.appendCallNote(throwable.message ?: currentAppText(
                        "外呼失败，请稍后再试",
                        "Outbound call failed. Please try again later."
                    ))
                }
            }
        }
    }
}
