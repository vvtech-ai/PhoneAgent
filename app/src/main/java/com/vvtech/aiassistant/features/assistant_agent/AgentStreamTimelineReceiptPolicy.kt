package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.domain.task.BatchTaskReceiptState
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_timeline.CallAttemptIdentityInput
import com.vvtech.aiassistant.features.assistant_timeline.CallAttemptIdentityPolicy
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineEvent
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineReducer
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToCallPageDataAdapter
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineToClarificationStepsAdapter
import com.vvtech.aiassistant.features.assistant_timeline.TimelineAnchor
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey

/**
 * Online receipt bridge. Receipts are written to the timeline first; the legacy cards below are
 * projections kept while regular streaming text still uses the old active-draft path.
 */
internal object AgentStreamTimelineReceiptPolicy {
    fun appendSingleReceipt(
        state: Index9AssistantUiState,
        responseSessionId: String,
        callResult: CallResultPayload?,
        toolCallId: String?
    ): Index9AssistantUiState {
        val result = callResult ?: return state
        val anchorIndex = state.clarificationSteps.lastIndex.coerceAtLeast(0)
        val callAttemptId = result.metadata
            ?.get("callAttemptId")
            ?.trim()
            ?.takeIf(String::isNotBlank)
            ?: CallAttemptIdentityPolicy.resolve(
                CallAttemptIdentityInput(
                    callId = result.metadata?.get("callId"),
                    toolCallId = toolCallId,
                    messageIndex = anchorIndex,
                    toolName = "makeCall",
                    fallbackAnchor = "online:$responseSessionId:step:$anchorIndex"
                )
            ).value
        val item = ConversationTimelineItem(
            itemId = "single:$callAttemptId",
            sessionId = responseSessionId,
            taskId = state.taskId,
            anchor = TimelineAnchor(messageIndex = anchorIndex, toolCallId = toolCallId),
            orderKey = orderKey(state, anchorIndex),
            payload = ConversationTimelinePayload.SingleCallReceipt(
                callAttemptId = callAttemptId,
                receipt = result.toReceipt(callAttemptId),
                callId = result.metadata
                    ?.get("callId")
                    ?.trim()
                    ?.takeIf(String::isNotBlank),
                phoneNumber = result.metadata
                    ?.get("phoneNumber")
                    .orEmpty(),
            )
        )
        val timeline = ConversationTimelineReducer.reduce(
            state.timelineItems,
            ConversationTimelineEvent.Upsert(item)
        )
        val receiptStep = ConversationTimelineToClarificationStepsAdapter.adapt(listOf(item)).single()
        val projectedSteps = state.clarificationSteps.mergeNarrativeOrAppend(anchorIndex, receiptStep)
        return state.copy(
            timelineItems = timeline,
            clarificationSteps = projectedSteps,
            callPageData = ConversationTimelineToCallPageDataAdapter.adaptLatestSingleReceipt(
                items = timeline,
                fallback = state.callPageData,
                preserveFallbackTranscript = true,
            ),
            agentCallResult = receiptStep.callResult
        )
    }

    fun upsertBatchReceipt(
        state: Index9AssistantUiState,
        responseSessionId: String?,
        result: BatchCallResultPayload?,
        batchAttemptId: String?,
        stepIndex: Int
    ): Index9AssistantUiState {
        val receipt = result ?: return state
        val anchorIndex = stepIndex.coerceAtLeast(0)
        val stableBatchId = batchAttemptId?.trim()?.takeIf(String::isNotBlank)
            ?: "online:${responseSessionId.orEmpty()}:step:$anchorIndex"
        val item = ConversationTimelineItem(
            itemId = "batch:$stableBatchId",
            sessionId = responseSessionId,
            taskId = stableBatchId,
            anchor = TimelineAnchor(messageIndex = anchorIndex, toolCallId = stableBatchId),
            orderKey = orderKey(state, anchorIndex),
            payload = ConversationTimelinePayload.BatchCallReceipt(
                batchAttemptId = stableBatchId,
                receipt = receipt.toReceipt(stableBatchId)
            )
        )
        val batchSingleAttemptIds = state.timelineItems
            .asSequence()
            .filter { it.taskId == stableBatchId }
            .mapNotNull { (it.payload as? ConversationTimelinePayload.SingleCallReceipt)?.callAttemptId }
            .toSet()
        val timelineWithoutBatchSingles = state.timelineItems.filterNot { timelineItem ->
            timelineItem.taskId == stableBatchId &&
                timelineItem.payload is ConversationTimelinePayload.SingleCallReceipt
        }
        val timeline = ConversationTimelineReducer.reduce(
            timelineWithoutBatchSingles,
            ConversationTimelineEvent.Upsert(item)
        )
        val receiptStep = ConversationTimelineToClarificationStepsAdapter.adapt(listOf(item)).single()
        val stepsWithoutBatchSingles = state.clarificationSteps.filterNot { step ->
            step.callResult?.metadata?.get("callAttemptId") in batchSingleAttemptIds
        }
        return state.copy(
            timelineItems = timeline,
            clarificationSteps = stepsWithoutBatchSingles.replaceOrAppend(anchorIndex, receiptStep)
        )
    }

    private fun orderKey(state: Index9AssistantUiState, messageIndex: Int): TimelineOrderKey {
        val nextIntraIndex = state.timelineItems
            .filter { it.orderKey.messageIndex == messageIndex }
            .maxOfOrNull { it.orderKey.intraMessageIndex }
            ?.plus(1)
            ?: 1
        return TimelineOrderKey(messageIndex, nextIntraIndex)
    }

    private fun List<ClarificationStep>.replaceOrAppend(index: Int, step: ClarificationStep): List<ClarificationStep> =
        if (index in indices) toMutableList().apply { this[index] = step } else this + step

    private fun List<ClarificationStep>.mergeNarrativeOrAppend(
        index: Int,
        receiptStep: ClarificationStep
    ): List<ClarificationStep> {
        if (index !in indices) return this + receiptStep
        val currentStep = this[index]
        if (currentStep.role != receiptStep.role) return this + receiptStep
        val mergedStep = receiptStep.copy(
            text = currentStep.text.ifBlank { receiptStep.text }
        )
        return toMutableList().apply { this[index] = mergedStep }
    }

    private fun CallResultPayload.toReceipt(callAttemptId: String) = TaskReceiptItemState(
        itemId = callAttemptId,
        targetName = metadata?.get("targetName").orEmpty(),
        status = status,
        headline = headline,
        detail = detail,
        transcript = metadata?.get("dialogueTranscript")
            ?: detail.takeIf { it.contains("assistant:", ignoreCase = true) || it.contains("callee:", ignoreCase = true) },
        receiptFields = receiptFields.orEmpty(),
    )

    private fun BatchCallResultPayload.toReceipt(batchId: String) = BatchTaskReceiptState(
        batchId = batchId,
        status = status,
        headline = headline,
        items = items.map(::toTaskReceiptItem)
    )

    private fun toTaskReceiptItem(item: BatchCallItemResultPayload) = TaskReceiptItemState(
        itemId = item.itemId,
        targetName = item.targetName,
        status = item.status,
        headline = item.headline,
        detail = item.detail,
        attemptCount = item.attemptCount,
        recalled = item.recalled,
        abnormal = item.abnormal,
        transcript = item.transcript
    )
}
