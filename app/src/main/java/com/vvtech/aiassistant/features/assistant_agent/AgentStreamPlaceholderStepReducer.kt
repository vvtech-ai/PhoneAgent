package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole

internal object AgentStreamPlaceholderStepReducer {

    fun clearRecoverablePlaceholder(
        steps: List<ClarificationStep>,
        stepIndex: Int
    ): List<ClarificationStep> {
        if (stepIndex !in steps.indices) return steps
        val step = steps[stepIndex]
        val canRemove = step.toolCalls.isNullOrEmpty() &&
            step.toolCards.isEmpty() &&
            step.callConfirmSpec == null
        return if (canRemove) {
            steps.toMutableList().apply { removeAt(stepIndex) }
        } else {
            steps.toMutableList().apply {
                this[stepIndex] = step.copy(streaming = false)
            }
        }
    }

    fun applyErrorPlaceholder(
        step: ClarificationStep,
        safeErrorText: String
    ): ClarificationStep {
        return step.copy(text = if (step.text.isBlank()) "（$safeErrorText）" else step.text)
    }

    fun newRetryStep(nowMs: Long): ClarificationStep {
        return ClarificationStep(
            role = VoiceRole.Assistant,
            text = "",
            status = "",
            streaming = true,
            thinkingStartedAt = nowMs
        )
    }
}
