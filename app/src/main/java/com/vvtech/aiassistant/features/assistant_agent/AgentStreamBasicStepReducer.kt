package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.ClarificationStep

internal object AgentStreamBasicStepReducer {

    fun appendThinking(step: ClarificationStep, text: String): ClarificationStep {
        val normalized = text.trim()
        if (normalized.isBlank()) return step
        val current = step.thinking.orEmpty().trim()
        return step.copy(thinking = if (current.isBlank()) normalized else "$current\n$normalized")
    }

    fun applyThinkingDone(step: ClarificationStep, durationMs: Long): ClarificationStep {
        return step.copy(thinkingDurationMs = durationMs)
    }

    fun appendText(step: ClarificationStep, text: String): ClarificationStep {
        return step.copy(text = step.text + text)
    }

    fun appendStatusEvent(step: ClarificationStep, text: String): ClarificationStep {
        val normalized = text.trim()
        if (normalized.isBlank()) return step
        val events = (step.callStatusEvents + normalized)
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .takeLast(MAX_STATUS_EVENTS)
        return step.copy(callStatusEvents = events)
    }

    private const val MAX_STATUS_EVENTS = 8
}
