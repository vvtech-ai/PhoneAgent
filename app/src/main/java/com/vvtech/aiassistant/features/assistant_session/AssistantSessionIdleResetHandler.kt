package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultConfirmLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleExample
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultRetryLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.flow.update

internal class AssistantSessionIdleResetHandler(
    private val viewModel: AssistantViewModel
) {
    fun resetToIdleHome() {
        viewModel.stopCallSessionPolling()
        viewModel.stopTakeoverAudioSocket()
        viewModel.takeoverReconnectJob?.cancel()
        viewModel.cancelTextProcessingStatusProgress()
        viewModel.lastAppliedCallStatusAt = null
        viewModel.lastAppliedCallDialogueDetail = null
        viewModel.takeoverStateProtectUntilElapsed = 0L
        viewModel.takeoverAudioEarliestStartElapsed = 0L
        viewModel.autoResumeListeningJob?.cancel()
        viewModel.pendingFreshTask = false
        viewModel.speechFallbackStarted = false
        viewModel.platformSpeechFallbackStarted = false
        viewModel.primarySummaryAction = null
        viewModel.pendingDetailActionable = null
        viewModel.detailSupplementCompletedTaskId = null
        viewModel.detailSupplementContactTaskId = null
        viewModel.detailSupplementContactValue = null
        viewModel.detailSupplementInfoTaskId = null
        viewModel.detailSupplementInfoValue = null
        viewModel.queuedRecognizedTurns.clear()
        viewModel.pendingStructuredRecognizedTurn = null
        viewModel.latestRealtimeAssistantReplyForBackend = null
        viewModel.lastCommittedUserTranscript = null
        viewModel.lastCommittedAssistantTranscript = null
        viewModel.voiceRecognizedInputDedupTracker.reset()
        viewModel.voiceRecoverableTurnCoordinator.clear("idle_reset")
        viewModel.activeDialogContext = null
        viewModel.pendingDialogTargetScene = null
        viewModel.pendingCarryoverScene = null
        viewModel.pendingCarryoverUtterance = null
        viewModel.pendingSyntheticAssistantPrompt = null
        viewModel.consumedSelectionSheetTaskId = null
        viewModel.consumedSelectionSheetSignature = null
        viewModel.pendingSelectionContinuation = null
        viewModel.voiceTaskId = null
        viewModel.textTaskId = null
        viewModel.agentSessionId = null
        viewModel.pendingAiCallLaunch = false
        viewModel.outboundCallAudioSuppressed = false
        viewModel.activeInteractionChannel = InteractionChannel.NONE
        viewModel.localTtsPlaying = false
        val resetCallPageData = CallPageData(
            name = currentAppText("AI 助理", "AI Assistant"),
            sub = currentAppText("实时外呼", "Live outbound call"),
            status = currentAppText("等待发起", "Waiting to start"),
            transcript = emptyList()
        )
        viewModel.latestCallPageSeed = resetCallPageData
        viewModel.internalUiState.update {
            it.copy(
                loading = false,
                error = null,
                taskId = null,
                sceneType = "GENERAL",
                taskStatus = "INIT",
                unresolvedTaskErrorStatus = null,
                taskErrorRecoveryInProgress = false,
                stage = AssistantStage.Idle,
                status = DefaultIdleStatus,
                timelineItems = emptyList(),
                clarificationSteps = emptyList(),
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                selectionSheet = null,
                summary = null,
                detailSupplement = null,
                confirmLabel = DefaultConfirmLabel,
                retryLabel = DefaultRetryLabel,
                exampleText = DefaultIdleExample,
                voiceConnecting = false,
                voiceActive = false,
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                listening = false,
                processingTurn = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                callUiMode = CallUiMode.Ai,
                currentCallId = null,
                handoffInFlight = false,
                showAiCallPage = false,
                callPageData = resetCallPageData,
                agentOptions = null,
                agentQuestions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = null,
                agentCallSpec = null,
                agentCallResult = null
            )
        }
    }
}
