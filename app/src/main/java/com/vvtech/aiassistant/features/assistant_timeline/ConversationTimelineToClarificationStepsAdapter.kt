package com.vvtech.aiassistant.features.assistant_timeline

import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_conversation.policy.CallConfirmationPresentationPolicy

/**
 * Compatibility projection for legacy conversation renderers. It never decides
 * ordering: the timeline's [ConversationTimelineItem.orderKey] is authoritative.
 */
object ConversationTimelineToClarificationStepsAdapter {
    fun adapt(items: List<ConversationTimelineItem>): List<ClarificationStep> = items
        .sortedWith(
            compareBy<ConversationTimelineItem> { it.ledgerSequence ?: Long.MAX_VALUE }
                .thenBy { it.orderKey }
                .thenBy { it.itemId }
        )
        .mapNotNull(::toClarificationStep)

    private fun toClarificationStep(item: ConversationTimelineItem): ClarificationStep? = when (val payload = item.payload) {
        is ConversationTimelinePayload.UserMessage -> ClarificationStep(
            role = VoiceRole.User,
            text = payload.text,
            status = ""
        )

        is ConversationTimelinePayload.AssistantMessage -> ClarificationStep(
            role = VoiceRole.Assistant,
            text = payload.text,
            status = ""
        )

        is ConversationTimelinePayload.CallConfirmation -> ClarificationStep(
            role = VoiceRole.Assistant,
            text = CallConfirmationPresentationPolicy.displayText(payload.callSpec),
            status = "",
            callConfirmSpec = payload.callSpec,
            callConfirmIdentity = payload.toolCallId,
        )

        is ConversationTimelinePayload.ToolCard -> ClarificationStep(
            role = VoiceRole.Assistant,
            text = payload.summary,
            status = payload.status.orEmpty(),
            toolCards = listOf(
                ToolCardInfo(
                    id = item.itemId,
                    toolName = payload.toolName,
                    methodLabel = payload.toolName,
                    result = payload.summary,
                    status = payload.status.orEmpty()
                )
            )
        )

        is ConversationTimelinePayload.EnvironmentPrecheck -> ClarificationStep(
            role = VoiceRole.Assistant,
            text = payload.summary,
            status = payload.passed?.let { if (it) "PASSED" else "FAILED" }.orEmpty()
        )

        is ConversationTimelinePayload.SingleCallReceipt -> ClarificationStep(
            role = VoiceRole.Assistant,
            text = "",
            status = payload.receipt.status,
            callResult = payload.receipt.toLegacyCallResult(
                callAttemptId = payload.callAttemptId,
                callId = payload.callId,
            )
        )

        is ConversationTimelinePayload.BatchCallReceipt -> ClarificationStep(
            role = VoiceRole.Assistant,
            text = "",
            status = payload.receipt.status,
            batchCallResult = BatchCallResultPayload(
                status = payload.receipt.status,
                headline = payload.receipt.headline,
                batchId = payload.batchAttemptId,
                items = payload.receipt.items.map { receipt ->
                    BatchCallItemResultPayload(
                        itemId = receipt.itemId,
                        targetName = receipt.targetName,
                        phoneNumber = "",
                        status = receipt.status,
                        headline = receipt.headline,
                        detail = receipt.detail,
                        attemptCount = receipt.attemptCount,
                        recalled = receipt.recalled,
                        abnormal = receipt.abnormal,
                        transcript = receipt.transcript
                    )
                }
            )
        )

        is ConversationTimelinePayload.OcrImage -> null
    }
}

internal fun com.vvtech.aiassistant.domain.task.TaskReceiptItemState.toLegacyCallResult(
    callAttemptId: String,
    callId: String? = null,
): CallResultPayload = CallResultPayload(
    status = status,
    headline = headline,
    detail = detail,
    receiptFields = receiptFields,
    metadata = buildMap {
        put("callAttemptId", callAttemptId)
        callId?.takeIf { it.isNotBlank() }?.let { put("callId", it) }
        targetName.takeIf { it.isNotBlank() }?.let { put("targetName", it) }
        transcript?.takeIf { it.isNotBlank() }?.let { put("dialogueTranscript", it) }
    }.takeIf { it.isNotEmpty() }
)
