package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant_conversation.policy.CallConfirmationPresentationPolicy
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalPolicy
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalStepPatch

internal data class AgentStreamResponseStepInput(
    val response: AgentChatResponse,
    val displayText: String,
    val batchPatch: TaskBatchCallFinalStepPatch? = null,
    val includeThinkingAndTools: Boolean = false
)

internal object AgentStreamResponseStepReducer {

    fun visibleResponseDisplayText(response: AgentChatResponse): String {
        if (response.type == TYPE_BATCH_CALL_RESULT) {
            return TaskBatchCallFinalPolicy.displayText(
                result = response.batchCallResult,
                fallbackText = response.text.orEmpty()
            )
        }
        val text = responseDisplayText(response)
        return if (response.type == TYPE_CALL_RESULT && looksLikeTerminalCallResultProgress(text)) {
            ""
        } else {
            text
        }
    }

    fun callConfirmSpec(response: AgentChatResponse): CallSpecPayload? {
        return response.callSpec.takeIf { response.type == TYPE_MAKE_CALL_REQUEST }
    }

    fun callConfirmIdentity(response: AgentChatResponse): String? {
        if (callConfirmSpec(response) == null) return null
        return response.pendingToolCallId?.trim()?.takeIf(String::isNotBlank)
    }

    fun applyResponse(
        step: ClarificationStep,
        input: AgentStreamResponseStepInput
    ): ClarificationStep {
        val response = input.response
        val updated = step.copy(
            text = input.batchPatch?.text ?: mergedPayloadText(step.text, input.displayText),
            thinking = if (input.includeThinkingAndTools) {
                response.thinking ?: step.thinking
            } else {
                step.thinking
            },
            toolCalls = if (input.includeThinkingAndTools) {
                AgentStreamToolStepReducer.sanitizeToolCalls(response.toolCalls) ?: step.toolCalls
            } else {
                step.toolCalls
            },
            callConfirmSpec = callConfirmSpec(response) ?: step.callConfirmSpec,
            callConfirmIdentity = callConfirmIdentity(response) ?: step.callConfirmIdentity,
            batchCallResult = input.batchPatch?.batchCallResult
                ?: response.batchCallResult
                ?: step.batchCallResult,
            callStatusEvents = input.batchPatch?.callStatusEvents ?: step.callStatusEvents
        )
        return if (response.type == TYPE_CALL_RESULT) {
            withoutTerminalCallResultConversation(updated)
        } else {
            updated
        }
    }

    private fun mergedPayloadText(current: String, payloadText: String): String {
        val text = payloadText.trim()
        if (text.isBlank()) return current
        if (current.isBlank()) return text
        return current
    }

    private fun responseDisplayText(response: AgentChatResponse): String {
        val text = response.text?.trim().orEmpty()
        if (response.type != TYPE_MAKE_CALL_REQUEST) return text
        return CallConfirmationPresentationPolicy.displayText(
            callSpec = response.callSpec,
            fallbackText = text,
        )
    }

    private fun withoutTerminalCallResultConversation(step: ClarificationStep): ClarificationStep {
        val cleanedText = step.text
            .trim()
            .takeUnless(::looksLikeTerminalCallResultProgress)
            .orEmpty()
        val cleanedThinking = step.thinking
            ?.lineSequence()
            ?.map { it.trim() }
            ?.filter { it.isNotBlank() && !looksLikeTerminalCallResultProgress(it) }
            ?.joinToString("\n")
            ?.takeIf { it.isNotBlank() }
        return step.copy(text = cleanedText, thinking = cleanedThinking)
    }

    private fun looksLikeTerminalCallResultProgress(text: String): Boolean {
        val normalized = text.trim()
        if (normalized.isBlank()) return true
        return normalized == "通话已结束" ||
            normalized == "任务已完成" ||
            normalized == "任务未完成" ||
            normalized == "通话已取消" ||
            normalized == "通话已结束，结果未确认" ||
            normalized == "通话已结束，任务部分完成" ||
            normalized.startsWith("预订结果") ||
            normalized.startsWith("AI代打结果")
    }

    private const val TYPE_BATCH_CALL_RESULT = "BATCH_CALL_RESULT"
    private const val TYPE_CALL_RESULT = "CALL_RESULT"
    private const val TYPE_MAKE_CALL_REQUEST = "MAKE_CALL_REQUEST"
}
