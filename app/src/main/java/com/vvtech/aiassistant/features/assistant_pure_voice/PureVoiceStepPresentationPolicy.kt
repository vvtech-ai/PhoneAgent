package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep

/**
 * Keeps transient tool progress while streaming, then lets durable AI and
 * structured cards own the completed pure-voice presentation.
 */
internal object PureVoiceStepPresentationPolicy {
    fun normalize(step: ClarificationStep): ClarificationStep {
        val specializedCallDisplay = step.callConfirmSpec != null || step.callResult != null
        val dedupedCards = step.toolCards
            .associateBy { it.stablePresentationKey() }
            .values
            .toList()
            .filterNot { specializedCallDisplay && it.isMakeCallCard() }
        val visibleCards = if (step.streaming) {
            dedupedCards
        } else {
            dedupedCards.filter { it.isDurablePureVoiceCard() }
        }
        val hasStructuredDisplay = visibleCards.isNotEmpty() ||
            step.callConfirmSpec != null ||
            step.callResult != null ||
            step.batchCallResult != null ||
            step.callStatusEvents.isNotEmpty()
        val hideGenericToolTrace = hasStructuredDisplay || !step.streaming
        val partials = if (hideGenericToolTrace) {
            emptyList()
        } else {
            step.partialToolCalls
                .associateBy { it.id.ifBlank { it.name } }
                .values
                .toList()
        }
        val toolCalls = when {
            hideGenericToolTrace || partials.isNotEmpty() -> null
            else -> step.toolCalls
                ?.distinctBy { "${it.name}\u0000${it.args}\u0000${it.result}" }
                ?.takeIf(List<*>::isNotEmpty)
        }
        return step.copy(
            partialToolCalls = partials,
            toolCalls = toolCalls,
            toolCards = visibleCards,
        )
    }

    private fun ToolCardInfo.isMakeCallCard(): Boolean =
        toolName.normalizedToolName() == MAKE_CALL

    private fun ToolCardInfo.isDurablePureVoiceCard(): Boolean =
        toolName.normalizedToolName() in DURABLE_TOOL_CARDS

    private fun ToolCardInfo.stablePresentationKey(): String =
        id.trim().takeIf(String::isNotBlank)?.let { "id:$it" }
            ?: "semantic:${toolName.trim()}\u0000${methodLabel.trim()}\u0000${body.trim()}"

    private fun String.normalizedToolName(): String =
        lowercase().filter(Char::isLetterOrDigit)

    private const val MAKE_CALL = "makecall"
    private val DURABLE_TOOL_CARDS = setOf(
        "showoptions",
        "askuser",
        "requestpermission",
        "importdocument",
    )
}
