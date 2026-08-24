package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.core.model.ToolCallInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PartialToolCall
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal object AgentStreamToolStepReducer {

    fun finalizeStep(step: ClarificationStep, nowMs: Long): ClarificationStep {
        val sanitizedPartials = step.partialToolCalls.map { partial ->
            if (partial.result == null) {
                partial.copy(
                    argsPreview = "",
                    result = currentAppText("（已取消）", "(Canceled)"),
                    durationMs = nowMs - partial.startedAt
                )
            } else {
                partial.copy(argsPreview = "", result = completedLabel())
            }
        }
        val collapsedTools = if (step.partialToolCalls.isNotEmpty()) {
            step.partialToolCalls.mapNotNull { partial ->
                partial.result ?: return@mapNotNull null
                ToolCallInfo(name = partial.name, args = "", result = completedLabel())
            }
        } else {
            sanitizeToolCalls(step.toolCalls)
        }
        return step.copy(
            streaming = false,
            thinkingDurationMs = step.thinkingDurationMs ?: step.thinkingStartedAt?.let { nowMs - it },
            thinking = step.thinking?.takeIf { it.isNotBlank() },
            partialToolCalls = sanitizedPartials,
            toolCalls = if (!collapsedTools.isNullOrEmpty()) collapsedTools else step.toolCalls
        )
    }

    @Suppress("UNUSED_PARAMETER")
    fun applyToolCallStart(
        step: ClarificationStep,
        id: String,
        name: String,
        argsPartial: String
    ): ClarificationStep {
        val existing = step.partialToolCalls.firstOrNull { it.id == id && id.isNotBlank() }
        val nextPartials = if (existing != null) {
            step.partialToolCalls.map { partial ->
                if (partial.id == id) partial.copy(argsPreview = "") else partial
            }
        } else {
            step.partialToolCalls + PartialToolCall(
                id = id.ifBlank { "p_${step.partialToolCalls.size}" },
                name = name,
                argsPreview = ""
            )
        }
        return step.copy(partialToolCalls = nextPartials)
    }

    @Suppress("UNUSED_PARAMETER")
    fun applyToolCallComplete(
        step: ClarificationStep,
        id: String,
        name: String,
        args: String,
        result: String,
        nowMs: Long
    ): ClarificationStep {
        val replaced = step.partialToolCalls.toMutableList()
        val index = replaced.indexOfFirst { it.id == id && id.isNotBlank() }
        val nextPartials = if (index >= 0) {
            val old = replaced[index]
            replaced[index] = old.copy(
                argsPreview = "",
                result = completedLabel(),
                durationMs = nowMs - old.startedAt
            )
            replaced
        } else {
            replaced + PartialToolCall(
                id = id.ifBlank { "c_${replaced.size}" },
                name = name,
                argsPreview = "",
                result = completedLabel(),
                durationMs = 0
            )
        }
        return step.copy(partialToolCalls = nextPartials)
    }

    fun applyToolCard(step: ClarificationStep, card: ToolCardInfo): ClarificationStep {
        return step.copy(toolCards = upsertToolCard(step.toolCards, card))
    }

    fun sanitizeToolCalls(toolCalls: List<ToolCallInfo>?): List<ToolCallInfo>? = toolCalls?.map { tool ->
        ToolCallInfo(name = tool.name, args = "", result = completedLabel())
    }

    fun upsertToolCard(
        current: List<ToolCardInfo>,
        incoming: ToolCardInfo
    ): List<ToolCardInfo> {
        val matchIndex = current.indexOfFirst { existing ->
            when {
                incoming.id.isNotBlank() && existing.id == incoming.id -> true
                incoming.id.isBlank() && existing.id.isBlank() ->
                    existing.toolName == incoming.toolName &&
                        existing.methodLabel == incoming.methodLabel &&
                        existing.body == incoming.body
                else -> false
            }
        }
        return if (matchIndex >= 0) {
            current.toMutableList().apply { this[matchIndex] = incoming }
        } else {
            current + incoming
        }
    }

    private fun completedLabel(): String =
        currentAppText("已完成", "Completed")
}
