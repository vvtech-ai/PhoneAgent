package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.ClarificationStep

/** Keeps Compose item identity attached to conversation content instead of list position. */
internal object PureVoiceClarificationItemKeyPolicy {
    fun keys(steps: List<ClarificationStep>): List<String> {
        val occurrences = mutableMapOf<String, Int>()
        return steps.map { step ->
            val identity = step.fallbackIdentity()
            val occurrence = occurrences.getOrDefault(identity, 0)
            occurrences[identity] = occurrence + 1
            "clarification:$identity:$occurrence"
        }
    }

    private fun ClarificationStep.fallbackIdentity(): String = when {
        thinkingStartedAt != null -> "stream:$thinkingStartedAt"
        callResult != null -> "call:${callResult.identity().part()}"
        batchCallResult != null -> "batch:${batchCallResult.identity().part()}"
        !callConfirmIdentity.isNullOrBlank() -> "confirm:${callConfirmIdentity.trim().part()}"
        toolCards.any { it.id.isNotBlank() } -> "tools:${toolCards.map { it.id.trim() }.part()}"
        else -> "message:${role.name}:${isUserActionEcho}:${text.trim().part()}"
    }

    private fun CallResultPayload.identity(): String = metadata
        ?.let { values ->
            values["callAttemptId"]?.trim()?.takeIf(String::isNotEmpty)
                ?: values["callId"]?.trim()?.takeIf(String::isNotEmpty)
        }
        ?: listOf(status, headline, detail).part()

    private fun BatchCallResultPayload.identity(): String = batchId
        ?.trim()
        ?.takeIf(String::isNotEmpty)
        ?: items.map { it.itemId.trim() }.part()

    private fun List<String>.part(): String = joinToString(separator = "|") { it.part() }

    private fun String.part(): String = "$length:$this"
}
