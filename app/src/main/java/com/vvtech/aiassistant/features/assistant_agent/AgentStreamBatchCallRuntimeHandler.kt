package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalStepPatch

internal data class AgentStreamBatchCallRuntimeCallbacks(
    val beginOutboundCallAudioSuppression: (String) -> Unit,
    val endOutboundCallAudioSuppression: (String) -> Unit,
    val cancelTextProcessingStatusProgress: () -> Unit,
    val updateUiState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val mutateStep: (Int, (ClarificationStep) -> ClarificationStep) -> Unit
)

internal class AgentStreamBatchCallRuntimeHandler(
    private val callbacks: AgentStreamBatchCallRuntimeCallbacks,
    private val activeState: AgentStreamBatchCallActiveStateHolder = AgentStreamBatchCallActiveStateHolder()
) {
    fun isActive(): Boolean = activeState.isActive()

    fun isActiveStep(stepIndex: Int): Boolean = activeState.isActiveStep(stepIndex)

    fun currentBatchId(): String = activeState.currentBatchId()

    fun markStream(stepIndex: Int, batchId: String?, total: Int) {
        callbacks.beginOutboundCallAudioSuppression(REASON_BATCH_STARTED)
        activeState.markStream(stepIndex = stepIndex, batchId = batchId, total = total)
    }

    fun clear() {
        val hadActiveBatchCall = activeState.clear()
        if (hadActiveBatchCall) {
            callbacks.endOutboundCallAudioSuppression(REASON_BATCH_FINISHED)
        }
    }

    fun holdUi() {
        callbacks.beginOutboundCallAudioSuppression(REASON_BATCH_ACTIVE)
        callbacks.cancelTextProcessingStatusProgress()
        callbacks.updateUiState { state ->
            state.copy(
                processingTurn = true,
                listening = false,
                voiceConnecting = false,
                voiceActive = false,
                voiceManuallyPaused = false,
                voiceBackgroundPaused = false,
                apiAsrListening = false,
                apiAsrPartialText = null,
                apiTtsPlaying = false,
                localTtsSpeaking = false,
                error = null,
                status = BATCH_CALL_ACTIVE_STATUS
            )
        }
    }

    fun applyProgress(stepIndex: Int, event: AgentStreamEvent.StatusDelta, text: String) {
        val update = activeState.applyProgress(stepIndex = stepIndex, event = event, text = text)
        if (!update.handled) return
        callbacks.beginOutboundCallAudioSuppression(REASON_BATCH_STARTED)
        holdUi()
        val snapshot = update.snapshot ?: return
        callbacks.updateUiState { state ->
            AgentStreamTimelineReceiptPolicy.upsertBatchReceipt(
                state = state,
                responseSessionId = state.taskId,
                result = snapshot,
                batchAttemptId = event.batchId ?: currentBatchId().takeIf(String::isNotBlank),
                stepIndex = stepIndex
            )
        }
    }

    fun buildFinalStepPatch(
        step: ClarificationStep,
        payloadText: String,
        payloadBatchCallResult: BatchCallResultPayload?
    ): TaskBatchCallFinalStepPatch {
        return activeState.buildFinalStepPatch(
            currentText = step.text,
            currentBatchCallResult = step.batchCallResult,
            currentCallStatusEvents = step.callStatusEvents,
            payloadText = payloadText,
            payloadBatchCallResult = payloadBatchCallResult
        )
    }

    private companion object {
        const val REASON_BATCH_STARTED = "batch_call_stream_started"
        const val REASON_BATCH_ACTIVE = "batch_call_stream_active"
        const val REASON_BATCH_FINISHED = "batch_call_stream_finished"
        const val BATCH_CALL_ACTIVE_STATUS = "正在执行多路外呼，完成后会汇总结果"
    }
}
