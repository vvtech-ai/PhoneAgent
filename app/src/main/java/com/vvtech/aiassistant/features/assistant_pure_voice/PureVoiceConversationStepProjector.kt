package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_conversation.policy.CallConfirmationIdentityPolicy

/**
 * The final display projection shared by live and restored pure-voice conversations.
 * Deduplication is deliberately scoped to one user turn so legitimate repeated text
 * and repeated actions in later turns remain visible.
 */
internal object PureVoiceConversationStepProjector {
    fun project(sourceSteps: List<ClarificationStep>): List<ClarificationStep> =
        projectWithBoundaries(sourceSteps).steps

    fun projectWithBoundaries(sourceSteps: List<ClarificationStep>): PureVoiceConversationProjection {
        val projected = mutableListOf<ClarificationStep>()
        val displayBoundaries = MutableList(sourceSteps.size + 1) { 0 }
        var assistantTurnStart = 0

        sourceSteps.forEachIndexed { sourceIndex, sourceStep ->
            if (sourceStep.role == VoiceRole.User) {
                projected += sourceStep
                if (!sourceStep.isUserActionEcho) {
                    assistantTurnStart = projected.size
                }
            } else {
                projectAssistantStep(
                    projected = projected,
                    assistantTurnStart = assistantTurnStart,
                    sourceStep = PureVoiceStepPresentationPolicy.normalize(sourceStep),
                )
            }
            displayBoundaries[sourceIndex + 1] = projected.size
        }

        return PureVoiceConversationProjection(projected, displayBoundaries)
    }
    private fun projectAssistantStep(
        projected: MutableList<ClarificationStep>,
        assistantTurnStart: Int,
        sourceStep: ClarificationStep,
    ) {
        if (!sourceStep.hasVisibleContent()) return

        if (mergeShowOptionsWithinTurn(projected, assistantTurnStart, sourceStep)) return

        val sameTextIndex = projected.indexOfLastInTurn(assistantTurnStart) { existing ->
            sourceStep.text.isNotBlank() &&
                existing.text.trim() == sourceStep.text.trim() &&
                (existing.hasPresentation() || sourceStep.hasPresentation()) &&
                existing.canMergePresentationWith(sourceStep)
        }
        if (sameTextIndex >= 0) {
            projected[sameTextIndex] = mergeSteps(projected[sameTextIndex], sourceStep)
            return
        }

        val callConfirmation = sourceStep.callConfirmSpec
        if (callConfirmation != null) {
            val ownerIndex = projected.indexOfLastInTurn(assistantTurnStart) {
                it.hasSameCallConfirmationAs(sourceStep)
            }
            if (ownerIndex >= 0) {
                val owner = projected[ownerIndex]
                if (owner.text.isBlank() || sourceStep.text.isBlank() ||
                    owner.text.trim() == sourceStep.text.trim()
                ) {
                    projected[ownerIndex] = mergeSteps(owner, sourceStep)
                    return
                }
                val withoutDuplicateConfirmation = sourceStep.copy(
                    callConfirmSpec = null,
                    callConfirmIdentity = null,
                )
                if (withoutDuplicateConfirmation.hasVisibleContent()) {
                    projected += withoutDuplicateConfirmation
                }
                return
            }
        }

        val callReceipt = sourceStep.callResult
        if (callReceipt != null) {
            val receiptIdentity = callReceipt.stableIdentity()
            val ownerIndex = projected.indexOfLastInTurn(assistantTurnStart) {
                if (receiptIdentity != null) {
                    it.callResult.stableIdentity() == receiptIdentity
                } else {
                    it.callResult == callReceipt
                }
            }
            if (ownerIndex >= 0) {
                val owner = projected[ownerIndex]
                if (owner.text.isBlank() || sourceStep.text.isBlank() ||
                    owner.text.trim() == sourceStep.text.trim()
                ) {
                    projected[ownerIndex] = mergeSteps(owner, sourceStep)
                    return
                }
                val withoutDuplicateReceipt = sourceStep.copy(callResult = null)
                if (withoutDuplicateReceipt.hasVisibleContent()) {
                    projected += withoutDuplicateReceipt
                }
                return
            }
        }

        val batchReceipt = sourceStep.batchCallResult
        if (batchReceipt != null) {
            val batchIdentity = batchReceipt.stableIdentity()
            val ownerIndex = projected.indexOfLastInTurn(assistantTurnStart) {
                if (batchIdentity != null) {
                    it.batchCallResult.stableIdentity() == batchIdentity
                } else {
                    it.batchCallResult == batchReceipt
                }
            }
            if (ownerIndex >= 0) {
                val owner = projected[ownerIndex]
                if (owner.text.isBlank() || sourceStep.text.isBlank() ||
                    owner.text.trim() == sourceStep.text.trim()
                ) {
                    projected[ownerIndex] = mergeSteps(owner, sourceStep)
                    return
                }
                val withoutDuplicateReceipt = sourceStep.copy(batchCallResult = null)
                if (withoutDuplicateReceipt.hasVisibleContent()) {
                    projected += withoutDuplicateReceipt
                }
                return
            }
        }

        val previousIndex = projected.lastIndex
        val previous = projected.getOrNull(previousIndex)
        if (previousIndex >= assistantTurnStart &&
            sourceStep.text.isNotBlank() &&
            sourceStep.callConfirmSpec == null &&
            sourceStep.callResult == null &&
            sourceStep.batchCallResult == null &&
            sourceStep.callStatusEvents.isEmpty() &&
            sourceStep.toolCards.isEmpty() &&
            sourceStep.toolCalls.isNullOrEmpty() &&
            sourceStep.partialToolCalls.isEmpty() &&
            previous?.hasOnlyStructuredCards() == true
        ) {
            projected[previousIndex] = mergeSteps(previous, sourceStep)
            return
        }

        val unownedStep = sourceStep.withCardsOwnedBy(projected, assistantTurnStart)
        if (unownedStep.hasVisibleContent()) {
            projected += unownedStep
        }
    }
    private fun mergeShowOptionsWithinTurn(
        projected: MutableList<ClarificationStep>,
        assistantTurnStart: Int,
        incoming: ClarificationStep,
    ): Boolean {
        val incomingLabels = incoming.numberedOptionLabels()
        if (incomingLabels.isEmpty()) return false

        val incomingIsGeneric = incoming.isGenericShowOptions()
        val incomingOwnsShowOptions = incoming.hasShowOptionsCard()
        val matchIndex = projected.indexOfLastInTurn(assistantTurnStart) { existing ->
            val exactlyOneOwnsShowOptions = existing.hasShowOptionsCard() != incomingOwnsShowOptions
            existing.numberedOptionLabels() == incomingLabels &&
                (incomingIsGeneric || existing.isGenericShowOptions() || exactlyOneOwnsShowOptions)
        }
        if (matchIndex < 0) return false

        val existing = projected[matchIndex]
        val merged = when {
            existing.isGenericShowOptions() && !incomingIsGeneric ->
                mergeSteps(existing, incoming).copy(text = incoming.text)
            !existing.isGenericShowOptions() && incomingIsGeneric ->
                mergeSteps(existing, incoming).copy(text = existing.text)
            existing.hasShowOptionsCard() && !incomingOwnsShowOptions ->
                mergeSteps(existing, incoming).copy(text = existing.text)
            !existing.hasShowOptionsCard() && incomingOwnsShowOptions ->
                mergeSteps(existing, incoming).copy(text = incoming.text)
            else -> mergeSteps(existing, incoming)
        }
        val hasInterveningActionEcho = projected
            .subList(matchIndex + 1, projected.size)
            .any { it.role == VoiceRole.User && it.isUserActionEcho }
        if (hasInterveningActionEcho) {
            projected.removeAt(matchIndex)
            projected += merged
        } else {
            projected[matchIndex] = merged
        }
        return true
    }
    private fun ClarificationStep.withCardsOwnedBy(
        projected: MutableList<ClarificationStep>,
        assistantTurnStart: Int,
    ): ClarificationStep {
        if (toolCards.isEmpty()) return this
        val unowned = mutableListOf<ToolCardInfo>()
        toolCards.forEach { incoming ->
            val ownerIndex = projected.indexOfLastInTurn(assistantTurnStart) { existing ->
                existing.toolCards.any { it.stablePresentationKey() == incoming.stablePresentationKey() }
            }
            if (ownerIndex < 0) {
                unowned += incoming
            } else {
                val owner = projected[ownerIndex]
                projected[ownerIndex] = owner.copy(
                    toolCards = owner.toolCards
                        .filterNot { it.stablePresentationKey() == incoming.stablePresentationKey() } +
                        incoming
                )
            }
        }
        return copy(toolCards = unowned)
    }
    private fun mergeSteps(
        owner: ClarificationStep,
        incoming: ClarificationStep,
    ): ClarificationStep = PureVoiceStepPresentationPolicy.normalize(
        owner.copy(
            text = owner.text.ifBlank { incoming.text },
            status = incoming.status.ifBlank { owner.status },
            thinking = incoming.thinking?.takeIf(String::isNotBlank) ?: owner.thinking,
            toolCalls = incoming.toolCalls?.takeIf(List<*>::isNotEmpty) ?: owner.toolCalls,
            toolCards = owner.toolCards + incoming.toolCards,
            callConfirmSpec = owner.callConfirmSpec ?: incoming.callConfirmSpec,
            callConfirmIdentity = owner.callConfirmIdentity ?: incoming.callConfirmIdentity,
            callResult = incoming.callResult ?: owner.callResult,
            batchCallResult = incoming.batchCallResult ?: owner.batchCallResult,
            callStatusEvents = (owner.callStatusEvents + incoming.callStatusEvents).distinct(),
            streaming = incoming.streaming,
            thinkingStartedAt = owner.thinkingStartedAt ?: incoming.thinkingStartedAt,
            thinkingDurationMs = incoming.thinkingDurationMs ?: owner.thinkingDurationMs,
            partialToolCalls = owner.partialToolCalls + incoming.partialToolCalls,
        )
    )
    private fun ClarificationStep.hasPresentation(): Boolean =
        !toolCalls.isNullOrEmpty() ||
            toolCards.isNotEmpty() ||
            partialToolCalls.isNotEmpty() ||
            callConfirmSpec != null ||
            callResult != null ||
            batchCallResult != null ||
            callStatusEvents.isNotEmpty()
    private fun ClarificationStep.canMergePresentationWith(other: ClarificationStep): Boolean =
        (callConfirmSpec == null || other.callConfirmSpec == null || hasSameCallConfirmationAs(other)) &&
            callResult.compatibleWith(other.callResult) &&
            batchCallResult.compatibleWith(other.batchCallResult)

    private fun ClarificationStep.hasSameCallConfirmationAs(other: ClarificationStep): Boolean =
        CallConfirmationIdentityPolicy.representsSameConfirmation(
            leftSpec = callConfirmSpec,
            leftToolCallId = callConfirmIdentity,
            rightSpec = other.callConfirmSpec,
            rightToolCallId = other.callConfirmIdentity,
        )

    private fun CallResultPayload?.compatibleWith(other: CallResultPayload?): Boolean {
        if (this == null || other == null) return true
        val identity = stableIdentity()
        val otherIdentity = other.stableIdentity()
        return if (identity != null && otherIdentity != null) identity == otherIdentity else this == other
    }
    private fun BatchCallResultPayload?.compatibleWith(other: BatchCallResultPayload?): Boolean {
        if (this == null || other == null) return true
        val identity = stableIdentity()
        val otherIdentity = other.stableIdentity()
        return if (identity != null && otherIdentity != null) identity == otherIdentity else this == other
    }
    private fun ClarificationStep.hasVisibleContent(): Boolean =
        text.isNotBlank() ||
            !thinking.isNullOrBlank() ||
            hasPresentation() ||
            streaming
    private fun ClarificationStep.hasOnlyStructuredCards(): Boolean =
        text.isBlank() &&
            toolCards.isEmpty() &&
            toolCalls.isNullOrEmpty() &&
            partialToolCalls.isEmpty() &&
            (callConfirmSpec != null || callResult != null || batchCallResult != null) &&
            callStatusEvents.isEmpty()
    private fun ClarificationStep.isGenericShowOptions(): Boolean =
        text.lineSequence().firstOrNull()?.trim() == GENERIC_SHOW_OPTIONS_TITLE
    private fun ClarificationStep.hasShowOptionsCard(): Boolean =
        toolCards.any { it.toolName == SHOW_OPTIONS_TOOL_NAME }
    private fun ClarificationStep.numberedOptionLabels(): List<String> =
        text.lineSequence().mapNotNull { line ->
            NUMBERED_OPTION.matchEntire(line)?.groupValues?.getOrNull(1)?.trim()
        }.filter(String::isNotBlank).toList()
    private fun CallResultPayload?.stableIdentity(): String? = this
        ?.metadata
        ?.let { metadata ->
            metadata["callAttemptId"]?.trim()?.takeIf(String::isNotBlank)
                ?: metadata["callId"]?.trim()?.takeIf(String::isNotBlank)
        }
    private fun BatchCallResultPayload?.stableIdentity(): String? {
        val batch = this ?: return null
        val itemIds = batch.items.map { it.itemId.trim() }
        return itemIds
            .takeIf { keys -> keys.isNotEmpty() && batch.items.all { it.itemId.isNotBlank() } }
            ?.sorted()
            ?.joinToString("\u0001")
    }
    private fun ToolCardInfo.stablePresentationKey(): String =
        id.trim().takeIf(String::isNotBlank)?.let { "id:$it" }
            ?: "semantic:${toolName.trim()}\u0000${methodLabel.trim()}\u0000${body.trim()}"
    private inline fun List<ClarificationStep>.indexOfLastInTurn(
        assistantTurnStart: Int,
        predicate: (ClarificationStep) -> Boolean,
    ): Int {
        for (index in lastIndex downTo assistantTurnStart.coerceAtLeast(0)) {
            if (predicate(this[index])) return index
        }
        return -1
    }

    private const val GENERIC_SHOW_OPTIONS_TITLE = "搜到的结果"
    private const val SHOW_OPTIONS_TOOL_NAME = "showOptions"
    private val NUMBERED_OPTION =
        Regex("""^\s*\d+\s*[.、．]\s*([^（(|]+?)(?:\s*[（(|].*)?\s*$""")
}
