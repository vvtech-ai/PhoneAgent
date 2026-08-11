package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.viewmodel.AutoResumeListeningDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.MaxAiSpeechResumeDelayMillis
import com.vvtech.aiassistant.features.assistant.viewmodel.MinAiSpeechResumeDelayMillis
import com.vvtech.aiassistant.features.assistant_voice.VoiceListenTriggers
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal data class AssistantSessionVoicePostApplyContext(
    val session: AssistantSessionResponse,
    val actionablePresent: Boolean,
    val selectionSheetPresent: Boolean,
    val mappedStepsPresent: Boolean,
    val suppressRealtimeContinuation: Boolean,
    val keepRealtimeDialog: Boolean,
    val shouldPlayLatestAssistantPromptAfterVoiceStop: Boolean,
    val newestBackendAssistantPrompt: String?
)

internal class AssistantSessionVoicePostApplyHandler(
    private val viewModel: AssistantViewModel
) {
    fun handleAfterVoiceApply(context: AssistantSessionVoicePostApplyContext) {
        handleBackendPromptOrSelectionListening(context)
        handleAutoResumeListening(context)
        handleQueuedRecognizedTurns(context)
    }

    fun scheduleAutoResumeListening(delayMillis: Long) {
        viewModel.autoResumeListeningJob?.cancel()
        logAutoResume(
            eventType = "VOICE_AUTO_RESUME_SCHEDULED",
            result = "scheduled",
            reason = "session_post_apply",
            delayMillis = delayMillis
        )
        viewModel.internalLog(
            "scheduleAutoResumeListening runId=${viewModel.activeDialogRunId} delay=$delayMillis " +
                "scene=${viewModel.internalUiState.value.sceneType} status=${viewModel.internalUiState.value.status}"
        )
        viewModel.autoResumeListeningJob = viewModel.viewModelScope.launch {
            delay(delayMillis)
            val state = viewModel.internalUiState.value
            if (
                viewModel.isOutboundCallAudioSuppressed() ||
                state.processingTurn ||
                state.selectionSheet != null ||
                state.summary != null ||
                state.stage != AssistantStage.Clarifying ||
                state.listening
            ) {
                logAutoResume(
                    eventType = "VOICE_AUTO_RESUME_SKIPPED",
                    result = "skipped",
                    reason = autoResumeSkipReason(state),
                    delayMillis = delayMillis
                )
                return@launch
            }
            viewModel.internalUiState.update {
                it.copy(
                    listening = false,
                    processingTurn = false,
                    error = null,
                    status = reconnectingStatus()
                )
            }
            viewModel.internalLog(
                "scheduleAutoResumeListening fired runId=${viewModel.activeDialogRunId} scene=${state.sceneType} " +
                    "taskId=${state.taskId}"
            )
            logAutoResume(
                eventType = "VOICE_AUTO_RESUME_FIRED",
                result = "fired",
                reason = "session_post_apply_ready",
                delayMillis = delayMillis
            )
            viewModel.startApiListening(VoiceListenTriggers.SessionAutoResume)
        }
    }

    fun estimateAssistantResumeDelay(session: AssistantSessionResponse): Long {
        val assistantText = session.messages
            .asReversed()
            .firstNotNullOfOrNull(AssistantSessionDialogueStepPolicy::extractVisibleAssistantDialogueText)
            .orEmpty()
        if (assistantText.isBlank()) {
            return AutoResumeListeningDelayMillis
        }
        val estimated = 240L + assistantText.length * 12L
        return estimated.coerceIn(MinAiSpeechResumeDelayMillis, MaxAiSpeechResumeDelayMillis)
    }

    private fun handleBackendPromptOrSelectionListening(context: AssistantSessionVoicePostApplyContext) {
        if (context.shouldPlayLatestAssistantPromptAfterVoiceStop) {
            viewModel.pendingAutoListenAfterSelectionPrompt = context.selectionSheetPresent
            viewModel.playBackendAssistantPromptFully(context.newestBackendAssistantPrompt)
            return
        }
        if (
            viewModel.activeInteractionChannel == InteractionChannel.VOICE &&
            context.selectionSheetPresent &&
            !context.actionablePresent
        ) {
            viewModel.internalLog("applySession resume selection voice without backend prompt")
            viewModel.pendingAutoListenAfterSelectionPrompt = true
            viewModel.resumeVoiceSelectionListeningAfterPrompt()
            return
        }
        viewModel.pendingAutoListenAfterSelectionPrompt = false
    }

    private fun handleAutoResumeListening(context: AssistantSessionVoicePostApplyContext) {
        if (
            !context.actionablePresent &&
            !context.selectionSheetPresent &&
            context.mappedStepsPresent &&
            !context.keepRealtimeDialog &&
            !context.suppressRealtimeContinuation
        ) {
            scheduleAutoResumeListening(estimateAssistantResumeDelay(context.session))
        } else {
            viewModel.autoResumeListeningJob?.cancel()
            logAutoResume(
                eventType = "VOICE_AUTO_RESUME_CANCELLED",
                result = "cancelled",
                reason = "post_apply_not_eligible"
            )
        }
    }

    private fun handleQueuedRecognizedTurns(context: AssistantSessionVoicePostApplyContext) {
        if (!context.actionablePresent && !context.selectionSheetPresent) {
            viewModel.drainQueuedRecognizedTurn()
        } else {
            viewModel.queuedRecognizedTurns.clear()
        }
    }

    private fun reconnectingStatus(): String = when (viewModel.currentVoiceLanguage()) {
        VoiceLanguage.English -> "Reconnecting voice..."
        VoiceLanguage.Japanese -> "音声に再接続しています..."
        VoiceLanguage.Chinese -> "正在重新连接语音..."
    }

    private fun autoResumeSkipReason(state: Index9AssistantUiState): String = when {
        viewModel.isOutboundCallAudioSuppressed() -> "call_audio_suppressed"
        state.processingTurn -> "processing_turn"
        state.selectionSheet != null -> "selection_present"
        state.summary != null -> "summary_present"
        state.stage != AssistantStage.Clarifying -> "stage_not_clarifying"
        state.listening -> "already_listening"
        else -> "unknown_gate"
    }

    private fun logAutoResume(
        eventType: String,
        result: String,
        reason: String,
        delayMillis: Long? = null
    ) {
        val state = viewModel.internalUiState.value
        RuntimeStateLogger.info(
            RuntimeStateLogEvent(
                domain = RuntimeStateLogDomain.VOICE,
                eventType = eventType,
                sessionId = viewModel.agentSessionId,
                taskId = state.taskId,
                callId = state.currentCallId,
                trigger = VoiceListenTriggers.SessionAutoResume,
                result = result,
                reason = reason,
                elapsedMs = delayMillis,
                attributes = mapOf(
                    "processingTurn" to state.processingTurn.toString(),
                    "listening" to state.listening.toString(),
                    "showAiCallPage" to state.showAiCallPage.toString()
                )
            )
        )
    }
}
