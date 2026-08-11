package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.features.assistant_conversation.policy.CallConfirmationIdentityPolicy
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToCallPageDataAdapter
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToClarificationStepsAdapter
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import com.vvtech.aiassistant.features.assistant_timeline.toLegacyCallResult

/** One projection boundary for every UI field derived from a committed timeline snapshot. */
internal data class TimelineSnapshotUiProjection(
    val sessionId: String,
    val timelineItems: List<ConversationTimelineItem>,
    val clarificationSteps: List<ClarificationStep>,
    val conversationStatus: String,
    val conversationContinuable: Boolean,
    val pendingToolRestorable: Boolean,
    private val latestSingleReceipt: ConversationTimelineItem?,
    private val reportedCallAttemptIds: Set<String> = emptySet(),
    private val callAttemptIdByCallId: Map<String, String> = emptyMap(),
    val ledgerHeadSequence: Long = 0L,
    val taskResultReplies: List<TimelineTaskResultReply> = emptyList(),
) {
    val hasTerminalCallReceipt: Boolean
        get() = (latestSingleReceipt?.payload as? ConversationTimelinePayload.SingleCallReceipt)
            ?.receipt
            ?.status
            ?.isTerminalCallStatus() == true

    fun hasTerminalCallReceipt(callAttemptId: String): Boolean {
        val expectedId = callAttemptId.trim().takeIf(String::isNotEmpty) ?: return false
        return timelineItems.any { item ->
            val receipt = item.payload as? ConversationTimelinePayload.SingleCallReceipt
                ?: return@any false
            receipt.callAttemptId == expectedId && receipt.receipt.status.isTerminalCallStatus()
        }
    }

    fun terminalReceiptSequence(
        responseType: String,
        callAttemptId: String?,
        batchId: String?,
    ): Long? {
        val normalizedType = responseType.trim().uppercase()
        return timelineItems.mapNotNull { item ->
            val sequence = item.ledgerSequence ?: return@mapNotNull null
            val matches = when (val payload = item.payload) {
                is ConversationTimelinePayload.SingleCallReceipt ->
                    normalizedType == "CALL_RESULT" &&
                        callAttemptId.matchesOptionalIdentity(payload.callAttemptId) &&
                        payload.receipt.status.isTerminalCallStatus()

                is ConversationTimelinePayload.BatchCallReceipt ->
                    normalizedType == "BATCH_CALL_RESULT" &&
                        batchId.matchesOptionalIdentity(
                            payload.receipt.batchId ?: payload.batchAttemptId
                        ) &&
                        payload.isTerminal()

                else -> false
            }
            sequence.takeIf { matches }
        }.maxOrNull()
    }

    fun hasReportedCallOutcomeForCallId(callId: String): Boolean {
        val expectedCallId = callId.trim().takeIf(String::isNotEmpty) ?: return false
        val attemptId = callAttemptIdByCallId[expectedCallId] ?: return false
        return attemptId in reportedCallAttemptIds
    }

    fun reduce(state: Index9AssistantUiState): Index9AssistantUiState {
        val receipt = latestSingleReceipt
            ?.payload as? ConversationTimelinePayload.SingleCallReceipt
        val terminalReceipt = receipt?.takeIf { it.receipt.status.isTerminalCallStatus() }
        val preserveActiveCallUi = state.currentCallId?.isNotBlank() == true && terminalReceipt == null
        val fallbackAttemptId = state.callPageData.callResult
            ?.metadata
            ?.get("callAttemptId")
        val samePendingConversation =
            (state.taskId.isNullOrBlank() || state.taskId == sessionId) &&
                state.callPageData.callResult == null &&
                state.callPageData.transcript.any { it.role != TranscriptRole.Note }
        val preserveCurrentCallTranscript =
            receipt != null &&
                (fallbackAttemptId == receipt.callAttemptId || samePendingConversation)
        val projectedCallPage = receipt?.let {
            ConversationTimelineToCallPageDataAdapter.adaptLatestSingleReceipt(
                items = listOf(requireNotNull(latestSingleReceipt)),
                fallback = state.callPageData,
                preserveFallbackTranscript = preserveCurrentCallTranscript,
            )
        }
        val projectedCallResult = terminalReceipt?.receipt?.toLegacyCallResult(
            callAttemptId = terminalReceipt.callAttemptId,
            callId = terminalReceipt.callId,
        )
        val projectedStatus = if (state.status == CALL_OUTCOME_SYNC_PENDING_STATUS && terminalReceipt != null) {
            terminalReceipt.receipt.headline
                .ifBlank { terminalReceipt.receipt.detail }
                .ifBlank { terminalReceipt.receipt.status }
        } else {
            state.status
        }
        val currentTerminalResult = state.currentTerminalCallResult()
        val currentTerminalAttemptId = currentTerminalResult
            ?.metadata
            ?.get("callAttemptId")
            ?.trim()
            ?.takeIf(String::isNotBlank)
        val preserveCurrentTerminal = currentTerminalResult != null &&
            currentTerminalAttemptId != null &&
            !hasTerminalCallReceipt(currentTerminalAttemptId)
        val canonicalProjectedResult = projectedCallResult
            ?.mergeIdentityFrom(currentTerminalResult)
        val projectedClarificationSteps = if (state.clarificationSteps.any { it.streaming }) {
            state.clarificationSteps
        } else {
            clarificationSteps.preserveCurrentSessionToolPresentation(state.clarificationSteps)
        }
        return state.copy(
            timelineItems = timelineItems,
            clarificationSteps = projectedClarificationSteps,
            taskStatus = conversationStatus,
            conversationContinuable = conversationContinuable,
            pendingToolRestorable = pendingToolRestorable,
            status = projectedStatus,
            callPageData = (preserveActiveCallUi || preserveCurrentTerminal)
                .thenKeep(state.callPageData, projectedCallPage),
            agentCallResult = when {
                preserveCurrentTerminal -> currentTerminalResult
                preserveActiveCallUi -> state.agentCallResult
                else -> canonicalProjectedResult
            },
        )
    }

    fun reduceAfterStreamOwnershipReleased(
        state: Index9AssistantUiState
    ): Index9AssistantUiState = reduce(
        state.copy(
            clarificationSteps = state.clarificationSteps.map { step ->
                if (step.streaming) step.copy(streaming = false) else step
            }
        )
    )

    private fun <T> Boolean.thenKeep(current: T, projected: T?): T =
        if (this) current else projected ?: current

    private fun Boolean.thenKeep(current: CallResultPayload?, projected: CallResultPayload?): CallResultPayload? =
        if (this) current else projected
}

internal data class TimelineTaskResultReply(
    val eventId: String,
    val sessionId: String,
    val sequence: Long,
    val text: String,
    val finishReason: String,
)

private fun String?.matchesOptionalIdentity(actual: String?): Boolean {
    val expected = this?.trim().orEmpty()
    return expected.isEmpty() || expected == actual?.trim()
}

private fun ConversationTimelinePayload.BatchCallReceipt.isTerminal(): Boolean =
    receipt.status.isTerminalCallStatus() ||
        (receipt.items.isNotEmpty() && receipt.items.all { it.isTerminal })

private fun Index9AssistantUiState.currentTerminalCallResult(): CallResultPayload? =
    agentCallResult
        ?.takeIf { it.status.isTerminalCallStatus() }
        ?: clarificationSteps.asReversed()
            .firstNotNullOfOrNull { it.callResult?.takeIf { result -> result.status.isTerminalCallStatus() } }
        ?: callPageData.callResult?.takeIf { it.status.isTerminalCallStatus() }

private fun CallResultPayload.mergeIdentityFrom(current: CallResultPayload?): CallResultPayload {
    val live = current ?: return this
    val projectedAttemptId = metadata?.get("callAttemptId")?.trim()
    val currentAttemptId = live.metadata?.get("callAttemptId")?.trim()
    if (projectedAttemptId.isNullOrBlank() || projectedAttemptId != currentAttemptId) return this
    return copy(
        metadata = live.metadata.orEmpty() + metadata.orEmpty(),
        receiptFields = receiptFields.takeIf { it.isNotEmpty() } ?: live.receiptFields,
    )
}

private fun List<ClarificationStep>.preserveCurrentSessionToolPresentation(
    currentSteps: List<ClarificationStep>
): List<ClarificationStep> {
    val merged = toMutableList()
    currentSteps.forEachIndexed { index, current ->
        val hasCurrentPresentation = !current.toolCalls.isNullOrEmpty() ||
            current.toolCards.isNotEmpty() ||
            current.partialToolCalls.isNotEmpty() ||
            current.callConfirmSpec != null ||
            current.callResult != null ||
            current.batchCallResult != null ||
            current.callStatusEvents.isNotEmpty()
        if (!hasCurrentPresentation) return@forEachIndexed

        val turnOrdinal = currentSteps.resolvePresentationTurnOrdinal(
            index = index,
            current = current,
            projected = merged,
        )
        val pendingUser = currentSteps
            .getOrNull(index - 1)
            ?.takeIf { it.role == VoiceRole.User }
        if (pendingUser != null && !pendingUser.isUserActionEcho) {
            // Any tool-backed round can finish before its user turn reaches the deferred snapshot.
            val currentOccurrences = currentSteps
                .take(index)
                .count { it.matchesTranscript(pendingUser) }
            val projectedOccurrences = merged.count { it.matchesTranscript(pendingUser) }
            if (projectedOccurrences < currentOccurrences) {
                merged.add(merged.insertionIndexForTurn(turnOrdinal), pendingUser)
            }
        }

        val normalizedText = current.text.trim()
        val turnCandidates = merged.indices.filter { candidateIndex ->
            merged.turnOrdinalAt(candidateIndex) == turnOrdinal &&
                merged[candidateIndex].role == current.role
        }
        val confirmationOwnerIndex = current.callConfirmSpec?.let {
            turnCandidates.lastOrNull { candidateIndex ->
                val projected = merged[candidateIndex]
                CallConfirmationIdentityPolicy.representsSameConfirmation(
                    leftSpec = projected.callConfirmSpec,
                    leftToolCallId = projected.callConfirmIdentity,
                    rightSpec = current.callConfirmSpec,
                    rightToolCallId = current.callConfirmIdentity,
                )
            }
        }
        merged.promoteCurrentTerminalPresentation(
            current = current,
            candidateIndices = turnCandidates,
        )
        val currentPresentation = current.withoutAlreadyProjectedStructuredCards(
            projected = merged,
            candidateIndices = turnCandidates,
        )
        val contentMatchIndex = normalizedText
            .takeIf { it.isNotEmpty() }
            ?.let { text ->
                turnCandidates.lastOrNull { candidateIndex ->
                    merged[candidateIndex].text.trim() == text &&
                        merged[candidateIndex].acceptsStructuredCardsFrom(currentPresentation)
                }
            }
        val isGenericShowOptionsResult =
            current.toolCards.any { it.toolName == "showOptions" } &&
                normalizedText.lineSequence().firstOrNull()?.trim() == "搜到的结果"
        val positionMatchIndex = turnCandidates.lastOrNull()
            ?.takeIf {
                (normalizedText.isEmpty() || isGenericShowOptionsResult) &&
                    !currentPresentation.hasStandaloneStructuredCard()
            }

        val presentationOwnerIndex = if (contentMatchIndex != null) {
            val projected = merged[contentMatchIndex]
            merged[contentMatchIndex] = projected.mergeCurrentPresentation(
                current = currentPresentation,
                preserveProjectedText = false,
            )
            contentMatchIndex
        } else if (confirmationOwnerIndex != null) {
            val projected = merged[confirmationOwnerIndex]
            merged[confirmationOwnerIndex] = projected.mergeCurrentPresentation(
                current = currentPresentation,
                preserveProjectedText = false,
            )
            confirmationOwnerIndex
        } else if (positionMatchIndex != null) {
            val projected = merged[positionMatchIndex]
            merged[positionMatchIndex] = projected.mergeCurrentPresentation(
                current = currentPresentation,
                preserveProjectedText = isGenericShowOptionsResult,
            )
            positionMatchIndex
        } else {
            val insertionIndex = turnCandidates.lastOrNull()?.plus(1)
                ?: merged.insertionIndexForTurn(turnOrdinal)
            val safeInsertionIndex = insertionIndex.coerceIn(0, merged.size)
            merged.add(safeInsertionIndex, currentPresentation)
            safeInsertionIndex
        }

        if (pendingUser?.isUserActionEcho == true) {
            val currentOccurrences = currentSteps
                .take(index)
                .count { it.matchesTranscript(pendingUser) }
            val projectedOccurrences = merged.count { it.matchesTranscript(pendingUser) }
            if (projectedOccurrences < currentOccurrences) {
                merged.add(presentationOwnerIndex.coerceIn(0, merged.size), pendingUser)
            }
        }
    }
    return merged
}

private fun MutableList<ClarificationStep>.promoteCurrentTerminalPresentation(
    current: ClarificationStep,
    candidateIndices: List<Int>,
) {
    current.callResult
        ?.takeIf { it.status.isTerminalCallStatus() }
        ?.let { currentTerminal ->
            val identity = currentTerminal.projectionIdentity() ?: return@let
            val pendingOwnerIndex = candidateIndices.lastOrNull { candidateIndex ->
                val projectedReceipt = this[candidateIndex].callResult
                projectedReceipt.projectionIdentity() == identity &&
                    projectedReceipt?.status?.isTerminalCallStatus() == false
            }
            if (pendingOwnerIndex != null) {
                this[pendingOwnerIndex] = this[pendingOwnerIndex].copy(
                    callResult = currentTerminal,
                    status = currentTerminal.status,
                )
            }
        }

    current.batchCallResult
        ?.takeIf { it.status.isTerminalCallStatus() }
        ?.let { currentTerminal ->
            val identity = currentTerminal.projectionIdentity() ?: return@let
            val pendingOwnerIndex = candidateIndices.lastOrNull { candidateIndex ->
                val projectedReceipt = this[candidateIndex].batchCallResult
                projectedReceipt.projectionIdentity() == identity &&
                    projectedReceipt?.status?.isTerminalCallStatus() == false
            }
            if (pendingOwnerIndex != null) {
                this[pendingOwnerIndex] = this[pendingOwnerIndex].copy(
                    batchCallResult = currentTerminal,
                    status = currentTerminal.status,
                )
            }
        }
}

private fun ClarificationStep.withoutAlreadyProjectedStructuredCards(
    projected: List<ClarificationStep>,
    candidateIndices: List<Int>,
): ClarificationStep {
    val duplicateCallConfirmation = candidateIndices.any { candidateIndex ->
        val existing = projected[candidateIndex]
        CallConfirmationIdentityPolicy.representsSameConfirmation(
            leftSpec = existing.callConfirmSpec,
            leftToolCallId = existing.callConfirmIdentity,
            rightSpec = callConfirmSpec,
            rightToolCallId = callConfirmIdentity,
        )
    }
    return copy(
        callConfirmSpec = callConfirmSpec?.takeUnless { duplicateCallConfirmation },
        callConfirmIdentity = callConfirmIdentity?.takeUnless { duplicateCallConfirmation },
        callResult = callResult?.takeUnless { candidate ->
            val identity = candidate.projectionIdentity() ?: return@takeUnless false
            candidateIndices.any { projected[it].callResult.projectionIdentity() == identity }
        },
        batchCallResult = batchCallResult?.takeUnless { candidate ->
            val identity = candidate.projectionIdentity()
            candidateIndices.any { candidateIndex ->
                val projectedBatch = projected[candidateIndex].batchCallResult
                if (identity != null) {
                    projectedBatch.projectionIdentity() == identity
                } else {
                    projectedBatch == candidate
                }
            }
        },
    )
}

private fun ClarificationStep.mergeCurrentPresentation(
    current: ClarificationStep,
    preserveProjectedText: Boolean,
): ClarificationStep = copy(
    text = if (preserveProjectedText) text else current.text.ifBlank { text },
    status = current.status.ifBlank { status },
    thinking = current.thinking ?: thinking,
    toolCalls = current.toolCalls?.takeIf { it.isNotEmpty() } ?: toolCalls,
    toolCards = (toolCards + current.toolCards).distinct(),
    callConfirmSpec = current.callConfirmSpec ?: callConfirmSpec,
    callConfirmIdentity = current.callConfirmIdentity ?: callConfirmIdentity,
    callResult = current.callResult ?: callResult,
    batchCallResult = current.batchCallResult ?: batchCallResult,
    callStatusEvents = (callStatusEvents + current.callStatusEvents).distinct(),
    streaming = current.streaming,
    thinkingStartedAt = current.thinkingStartedAt ?: thinkingStartedAt,
    thinkingDurationMs = current.thinkingDurationMs ?: thinkingDurationMs,
    partialToolCalls = current.partialToolCalls.ifEmpty { partialToolCalls },
)

private fun ClarificationStep.acceptsStructuredCardsFrom(current: ClarificationStep): Boolean =
    (callConfirmSpec == null || current.callConfirmSpec == null) &&
        (callResult == null || current.callResult == null) &&
        (batchCallResult == null || current.batchCallResult == null)

private fun ClarificationStep.hasStandaloneStructuredCard(): Boolean =
    callConfirmSpec != null || callResult != null || batchCallResult != null

private fun List<ClarificationStep>.turnOrdinalAt(index: Int): Int =
    take(index.coerceIn(0, lastIndex) + 1)
        .count { it.role == VoiceRole.User && !it.isUserActionEcho }

private fun List<ClarificationStep>.resolvePresentationTurnOrdinal(
    index: Int,
    current: ClarificationStep,
    projected: List<ClarificationStep>,
): Int {
    val currentOrdinal = turnOrdinalAt(index)
    val lostCurrentTurnAnchors = none { it.role == VoiceRole.User && !it.isUserActionEcho }
    val latestProjectedTurn = projected.count { it.role == VoiceRole.User && !it.isUserActionEcho }
    val matchedProjectedTurn = projected.indices
        .lastOrNull { projectedIndex ->
            current.matchesProjectedTerminalPresentation(projected[projectedIndex])
        }
        ?.let(projected::turnOrdinalAt)
    return if (
        current.hasTerminalCallReceiptPresentation() &&
        lostCurrentTurnAnchors &&
        latestProjectedTurn > currentOrdinal
    ) {
        matchedProjectedTurn ?: latestProjectedTurn
    } else {
        currentOrdinal
    }
}

private fun ClarificationStep.hasTerminalCallReceiptPresentation(): Boolean =
    callResult?.status?.isTerminalCallStatus() == true ||
        batchCallResult?.status?.isTerminalCallStatus() == true

private fun ClarificationStep.matchesProjectedTerminalPresentation(
    projected: ClarificationStep,
): Boolean {
    val singleIdentity = callResult.projectionIdentity()
    if (singleIdentity != null && singleIdentity == projected.callResult.projectionIdentity()) return true
    val batchIdentity = batchCallResult.projectionIdentity()
    if (batchIdentity != null && batchIdentity == projected.batchCallResult.projectionIdentity()) return true
    val normalizedText = text.trim()
    return normalizedText.isNotEmpty() &&
        role == projected.role &&
        normalizedText == projected.text.trim()
}

private fun List<ClarificationStep>.insertionIndexForTurn(turnOrdinal: Int): Int {
    val lastInTurn = indices.lastOrNull { turnOrdinalAt(it) == turnOrdinal }
    if (lastInTurn != null) return lastInTurn + 1
    return indices.firstOrNull { turnOrdinalAt(it) > turnOrdinal } ?: size
}

private fun CallResultPayload?.projectionIdentity(): String? = this
    ?.metadata
    ?.let { metadata ->
        metadata["callAttemptId"]?.trim()?.takeIf(String::isNotBlank)
            ?: metadata["callId"]?.trim()?.takeIf(String::isNotBlank)
    }

private fun BatchCallResultPayload?.projectionIdentity(): String? {
    val batch = this ?: return null
    val itemIds = batch.items.map { it.itemId.trim() }
    return itemIds
        .takeIf { keys -> keys.isNotEmpty() && batch.items.all { it.itemId.isNotBlank() } }
        ?.sorted()
        ?.joinToString("\u0001")
}

private fun ClarificationStep.matchesTranscript(other: ClarificationStep): Boolean =
    role == other.role &&
        text.trim() == other.text.trim() &&
        isUserActionEcho == other.isUserActionEcho

internal object TimelineSnapshotUiProjector {
    fun project(snapshot: ConversationTimelineSnapshot): TimelineSnapshotUiProjection {
        val items = snapshot.timeline.items
        val adapterOrderedItems = items.mapIndexed { index, item ->
            item.copy(orderKey = TimelineOrderKey(messageIndex = index))
        }
        return TimelineSnapshotUiProjection(
            sessionId = snapshot.sessionId,
            timelineItems = items,
            clarificationSteps = ConversationTimelineToClarificationStepsAdapter.adapt(adapterOrderedItems),
            conversationStatus = snapshot.projection.conversationStatus,
            conversationContinuable = snapshot.projection.conversationContinuable,
            pendingToolRestorable = snapshot.projection.pendingToolRestorable,
            latestSingleReceipt = items
                .filter { it.payload is ConversationTimelinePayload.SingleCallReceipt }
                .maxWithOrNull(
                    compareBy<ConversationTimelineItem> { it.ledgerSequence ?: Long.MIN_VALUE }
                        .thenBy { it.orderKey }
                        .thenBy { it.itemId },
                ),
            reportedCallAttemptIds = snapshot.events.asSequence()
                .filter { event ->
                    (event.type as? ConversationLedgerEventType.Known)?.stable ==
                        StableConversationLedgerEventType.CALL_OUTCOME_REPORTED
                }
                .mapNotNull { it.callAttemptId?.trim()?.takeIf(String::isNotEmpty) }
                .toSet(),
            callAttemptIdByCallId = snapshot.events.mapNotNull { event ->
                val callId = event.callId?.trim()?.takeIf(String::isNotEmpty)
                    ?: return@mapNotNull null
                val attemptId = event.callAttemptId?.trim()?.takeIf(String::isNotEmpty)
                    ?: return@mapNotNull null
                callId to attemptId
            }.toMap(),
            ledgerHeadSequence = snapshot.ledgerHeadSequence,
            taskResultReplies = snapshot.events.mapNotNull { event ->
                val type = event.type as? ConversationLedgerEventType.Known
                    ?: return@mapNotNull null
                if (type.stable != StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED) {
                    return@mapNotNull null
                }
                val finishReason = event.payload.projectionString("finishReason").lowercase()
                if (finishReason !in TASK_RESULT_FINISH_REASONS) return@mapNotNull null
                val text = event.payload.projectionString("text").takeIf(String::isNotBlank)
                    ?: return@mapNotNull null
                TimelineTaskResultReply(
                    eventId = event.eventId,
                    sessionId = event.sessionId,
                    sequence = event.sequence,
                    text = text,
                    finishReason = finishReason,
                )
            }.sortedBy(TimelineTaskResultReply::sequence),
        )
    }
}

private fun com.google.gson.JsonObject.projectionString(key: String): String {
    val value = get(key)?.takeUnless { it.isJsonNull } ?: return ""
    return runCatching { value.asString }.getOrDefault("").trim()
}

private val TASK_RESULT_FINISH_REASONS = setOf("call_result", "batch_call_result")

internal fun String.isTerminalCallStatus(): Boolean {
    val normalized = trim().uppercase()
    return normalized in TERMINAL_CALL_STATUSES || TERMINAL_CALL_MARKERS.any(normalized::contains)
}

private val TERMINAL_CALL_STATUSES = setOf(
    "COMPLETED",
    "SUCCESS",
    "DONE",
    "FINISHED",
    "ENDED",
    "FAILED",
    "INCOMPLETE",
    "PARTIAL",
    "PARTIALLY_COMPLETED",
    "NEEDS_FOLLOW_UP",
    "EXECUTION_ERROR",
    "UNCLEAR",
    "CANCELLED",
    "CANCELED",
    "REJECTED",
    "NOT_FOUND",
    "NO_ANSWER",
    "MISSED_CALL",
    "TIMEOUT",
    "USER_CANCELLED",
    "USER_CANCELED",
    "TERMINATED",
)
private val TERMINAL_CALL_MARKERS = setOf(
    "COMPLETED",
    "FAILED",
    "CANCELLED",
    "CANCELED",
    "REJECTED",
    "NOT_FOUND",
    "NO_ANSWER",
    "MISSED_CALL",
    "TIMEOUT",
    "ENDED",
    "TERMINATED",
)
