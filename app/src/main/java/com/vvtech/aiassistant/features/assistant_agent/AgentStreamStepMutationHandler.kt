package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalStepPatch

internal data class AgentStreamStepMutationCallbacks(
    val updateState: (((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit),
    val batchCallFinalStepPatch: (
        step: ClarificationStep,
        payloadText: String,
        payloadBatchCallResult: BatchCallResultPayload?
    ) -> TaskBatchCallFinalStepPatch?,
    val maybeTtsSignal: (String) -> Unit,
    val applyAgentResponseState: (AgentChatResponse) -> Unit,
    val currentVoiceLanguage: () -> VoiceLanguage,
    val releaseStreamOwnership: (Int) -> Unit = {},
)

internal class AgentStreamStepMutationHandler(
    private val callbacks: AgentStreamStepMutationCallbacks
) {
    fun appendAssistantStep(): Int {
        var resolved = -1
        callbacks.updateState { state ->
            val step = ClarificationStep(
                role = VoiceRole.Assistant,
                text = "",
                status = "",
                streaming = true,
                thinkingStartedAt = System.currentTimeMillis()
            )
            val newSteps = state.clarificationSteps + step
            resolved = newSteps.size - 1
            state.copy(clarificationSteps = newSteps)
        }
        return resolved
    }

    fun mutateStep(index: Int, mutator: (ClarificationStep) -> ClarificationStep) {
        callbacks.updateState { state ->
            if (index !in state.clarificationSteps.indices) return@updateState state
            val updated = state.clarificationSteps.toMutableList().apply {
                this[index] = mutator(this[index])
            }
            state.copy(clarificationSteps = updated)
        }
    }

    fun finalizeStep(index: Int) {
        mutateStep(index) { step ->
            AgentStreamToolStepReducer.finalizeStep(step, nowMs = System.currentTimeMillis())
        }
    }

    fun finalizeOrphanedStreamingSteps(): List<Int> {
        val finalized = mutableListOf<Int>()
        val nowMs = System.currentTimeMillis()
        callbacks.updateState { state ->
            val updated = state.clarificationSteps.mapIndexed { index, step ->
                if (step.streaming) {
                    finalized += index
                    AgentStreamToolStepReducer.finalizeStep(step, nowMs = nowMs)
                } else {
                    step
                }
            }
            if (finalized.isEmpty()) state else state.copy(clarificationSteps = updated)
        }
        return finalized
    }

    fun appendResponseStep(response: AgentChatResponse) {
        val text = assistantOutputText(visibleResponseDisplayText(response)).takeIf { it.isNotBlank() }
        if (!text.isNullOrBlank()) {
            val step = ClarificationStep(
                role = VoiceRole.Assistant,
                text = text,
                status = "",
                thinking = response.thinking?.let(::assistantOutputText),
                toolCalls = AgentStreamToolStepReducer.sanitizeToolCalls(response.toolCalls),
                callConfirmSpec = AgentStreamResponseStepReducer.callConfirmSpec(response),
                callConfirmIdentity = AgentStreamResponseStepReducer.callConfirmIdentity(response),
                batchCallResult = response.batchCallResult
            )
            callbacks.updateState { it.copy(clarificationSteps = it.clarificationSteps + step) }
        }
        callbacks.applyAgentResponseState(response)
    }

    fun fillPlaceholderWithResponse(stepIndex: Int, response: AgentChatResponse) {
        val text = assistantOutputText(visibleResponseDisplayText(response))
        mutateStep(stepIndex) { step ->
            AgentStreamResponseStepReducer.applyResponse(
                step = step,
                input = responseStepInput(
                    response = response,
                    displayText = text,
                    step = step,
                    includeThinkingAndTools = true
                )
            )
        }
        if (response.type == "TEXT_REPLY" && text.isNotBlank()) {
            callbacks.maybeTtsSignal(text)
        }
        finalizeStep(stepIndex)
        try {
            callbacks.applyAgentResponseState(response)
        } finally {
            callbacks.releaseStreamOwnership(stepIndex)
        }
    }

    private fun assistantOutputText(text: String): String =
        sanitizeUserFacingNetworkText(text, callbacks.currentVoiceLanguage())

    fun responseStepInput(
        response: AgentChatResponse,
        displayText: String,
        step: ClarificationStep,
        includeThinkingAndTools: Boolean = false
    ): AgentStreamResponseStepInput {
        val batchPatch = if (response.type == "BATCH_CALL_RESULT") {
            callbacks.batchCallFinalStepPatch(step, displayText, response.batchCallResult)
        } else {
            null
        }
        return AgentStreamResponseStepInput(
            response = response,
            displayText = displayText,
            displayThinking = response.thinking?.let(::assistantOutputText),
            batchPatch = batchPatch,
            includeThinkingAndTools = includeThinkingAndTools
        )
    }

    fun visibleResponseDisplayText(response: AgentChatResponse): String {
        return AgentStreamResponseStepReducer.visibleResponseDisplayText(response)
    }
}
