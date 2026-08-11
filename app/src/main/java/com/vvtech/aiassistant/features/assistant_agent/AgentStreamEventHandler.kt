package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingError

internal data class AgentStreamEventRuntimeCallbacks(
    val isVoiceMode: () -> Boolean,
    val currentVoiceLanguage: () -> VoiceLanguage,
    val cancelTextProcessingStatusProgress: () -> Unit,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val stopApiListening: () -> Unit,
    val loadConversations: () -> Unit,
    val logTts: (String) -> Unit,
    val logStream: (String) -> Unit
)

internal data class AgentStreamEventStepCallbacks(
    val mutateStep: (stepIndex: Int, mutator: (ClarificationStep) -> ClarificationStep) -> Unit,
    val finalizeStep: (stepIndex: Int) -> Unit,
    val responseStepInput: (
        response: AgentChatResponse,
        displayText: String,
        step: ClarificationStep
    ) -> AgentStreamResponseStepInput
)

internal data class AgentStreamEventVoiceCallbacks(
    val maybeTtsDelta: (String) -> Unit,
    val maybeTtsSignal: (String) -> Unit,
    val failVoiceStream: (AgentStreamEvent.Err) -> Nothing
)

internal data class AgentStreamEventBatchCallbacks(
    val markActiveStream: (stepIndex: Int, batchId: String?, total: Int) -> Unit,
    val holdUiForActiveStream: () -> Unit,
    val applyProgress: (stepIndex: Int, event: AgentStreamEvent.StatusDelta, text: String) -> Unit,
    val isActiveStep: (stepIndex: Int) -> Boolean,
    val clearActiveState: () -> Unit,
    val syncPendingStatusText: () -> String
)

internal data class AgentStreamEventResponseCallbacks(
    val applyResponseState: (AgentChatResponse) -> Unit
)

internal class AgentStreamEventHandler(
    private val runtime: AgentStreamEventRuntimeCallbacks,
    private val steps: AgentStreamEventStepCallbacks,
    private val voice: AgentStreamEventVoiceCallbacks,
    private val batch: AgentStreamEventBatchCallbacks,
    private val response: AgentStreamEventResponseCallbacks
) {
    fun apply(stepIndex: Int, event: AgentStreamEvent) {
        runtime.logTts("applyStreamEvent type=${event::class.simpleName} step=$stepIndex voice=${runtime.isVoiceMode()}")
        when (event) {
            is AgentStreamEvent.ThinkingDelta -> applyThinkingDelta(stepIndex, event)
            is AgentStreamEvent.StatusDelta -> applyStatusDelta(stepIndex, event)
            is AgentStreamEvent.ThinkingDone -> {
                steps.mutateStep(stepIndex) {
                    AgentStreamBasicStepReducer.applyThinkingDone(it, event.durationMs)
                }
            }
            is AgentStreamEvent.ToolCallStart -> applyToolCallStart(stepIndex, event)
            is AgentStreamEvent.ToolCallComplete -> applyToolCallComplete(stepIndex, event)
            is AgentStreamEvent.ToolCard -> {
                steps.mutateStep(stepIndex) { AgentStreamToolStepReducer.applyToolCard(it, event.card) }
            }
            is AgentStreamEvent.TextDelta -> {
                steps.mutateStep(stepIndex) { AgentStreamBasicStepReducer.appendText(it, event.text) }
                voice.maybeTtsDelta(event.text)
            }
            is AgentStreamEvent.Signal -> applyResponseEvent(stepIndex, event.payload, signalTts = false)
            is AgentStreamEvent.Final -> applyResponseEvent(stepIndex, event.payload, signalTts = true)
            is AgentStreamEvent.TimelineCommitted -> Unit
            is AgentStreamEvent.Err -> applyError(stepIndex, event)
            AgentStreamEvent.Done -> applyDone(stepIndex)
            AgentStreamEvent.Heartbeat -> Unit
        }
    }

    private fun applyThinkingDelta(stepIndex: Int, event: AgentStreamEvent.ThinkingDelta) {
        val text = event.text.trim().takeIf { it.isNotBlank() } ?: return
        steps.mutateStep(stepIndex) { step ->
            AgentStreamBasicStepReducer.appendThinking(step, text)
        }
    }

    private fun applyStatusDelta(stepIndex: Int, event: AgentStreamEvent.StatusDelta) {
        val text = event.text.trim().takeIf { it.isNotBlank() } ?: return
        batch.applyProgress(stepIndex, event, text)
        steps.mutateStep(stepIndex) { step ->
            AgentStreamBasicStepReducer.appendStatusEvent(step, text)
        }
        runtime.updateState { it.copy(status = text, processingTurn = true) }
    }

    private fun applyToolCallStart(stepIndex: Int, event: AgentStreamEvent.ToolCallStart) {
        runtime.logStream(
            "stream_tool_start step=$stepIndex voice=${runtime.isVoiceMode()} " +
                "name=${event.name} argsLen=${event.argsPartial.length}"
        )
        if (event.name.equals("makeBatchCalls", ignoreCase = true)) {
            batch.markActiveStream(stepIndex, null, 0)
            batch.holdUiForActiveStream()
        }
        steps.mutateStep(stepIndex) { step ->
            AgentStreamToolStepReducer.applyToolCallStart(
                step = step,
                id = event.id,
                name = event.name,
                argsPartial = event.argsPartial
            )
        }
    }

    private fun applyToolCallComplete(stepIndex: Int, event: AgentStreamEvent.ToolCallComplete) {
        runtime.logStream(
            "stream_tool_complete step=$stepIndex voice=${runtime.isVoiceMode()} " +
                "name=${event.name} argsLen=${event.args.length} resultLen=${event.result.length}"
        )
        steps.mutateStep(stepIndex) { step ->
            AgentStreamToolStepReducer.applyToolCallComplete(
                step = step,
                id = event.id,
                name = event.name,
                args = event.args,
                result = event.result,
                nowMs = System.currentTimeMillis()
            )
        }
    }

    private fun applyResponseEvent(
        stepIndex: Int,
        payload: AgentChatResponse,
        signalTts: Boolean
    ) {
        runtime.cancelTextProcessingStatusProgress()
        val payloadText = AgentStreamResponseStepReducer.visibleResponseDisplayText(payload)
        steps.mutateStep(stepIndex) { step ->
            AgentStreamResponseStepReducer.applyResponse(
                step = step,
                input = steps.responseStepInput(payload, payloadText, step)
            )
        }
        if (signalTts && payload.type == TYPE_TEXT_REPLY && payloadText.isNotBlank()) {
            voice.maybeTtsSignal(payloadText)
        }
        steps.finalizeStep(stepIndex)
        response.applyResponseState(payload)
    }

    private fun applyError(stepIndex: Int, event: AgentStreamEvent.Err) {
        if (runtime.isVoiceMode()) {
            voice.failVoiceStream(event)
        }
        val message = if (event.hasStructuredFailure) {
            event.message
        } else {
            sanitizeUserFacingError(event.message, runtime.currentVoiceLanguage())
        }
        runtime.cancelTextProcessingStatusProgress()
        steps.finalizeStep(stepIndex)
        runtime.updateState {
            AgentStreamErrorUiStateReducer.applyStreamError(it, message)
        }
    }

    private fun applyDone(stepIndex: Int) {
        steps.finalizeStep(stepIndex)
        if (!batch.isActiveStep(stepIndex)) return
        batch.clearActiveState()
        runtime.stopApiListening()
        runtime.updateState {
            AgentStreamErrorUiStateReducer.applyBatchSyncPending(
                state = it,
                statusText = batch.syncPendingStatusText(),
                clearError = false
            )
        }
        runtime.loadConversations()
    }

    private companion object {
        const val TYPE_TEXT_REPLY = "TEXT_REPLY"
    }
}
