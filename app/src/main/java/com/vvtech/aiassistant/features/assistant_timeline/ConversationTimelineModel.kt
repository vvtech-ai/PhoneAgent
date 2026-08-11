package com.vvtech.aiassistant.features.assistant_timeline

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.domain.task.BatchTaskReceiptState
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState

/**
 * The immutable display history for one task conversation. Runtime and restore paths
 * both write this shape; UI-specific models are intentionally not referenced here.
 */
data class ConversationTimelineItem(
    val itemId: String,
    val sessionId: String? = null,
    val taskId: String? = null,
    val anchor: TimelineAnchor = TimelineAnchor(),
    val orderKey: TimelineOrderKey,
    val payload: ConversationTimelinePayload,
    val createdAtEpochMs: Long? = null,
    /** Durable identity is optional until the ledger read path replaces legacy restore. */
    val ledgerSequence: Long? = null,
    val ledgerEventId: String? = null,
) {
    val kind: ConversationTimelineKind
        get() = payload.kind

    /** Stable key for adapters such as LazyColumn; never derived from list position. */
    val stableUiKey: String
        get() = "timeline:$itemId"
}

data class TimelineAnchor(
    val messageId: String? = null,
    val messageIndex: Int? = null,
    val toolCallId: String? = null,
    val toolResultId: String? = null
)

data class TimelineOrderKey(
    val messageIndex: Int,
    val intraMessageIndex: Int = 0
) : Comparable<TimelineOrderKey> {
    override fun compareTo(other: TimelineOrderKey): Int {
        return compareValuesBy(this, other, TimelineOrderKey::messageIndex, TimelineOrderKey::intraMessageIndex)
    }
}

enum class ConversationTimelineKind {
    UserMessage,
    AssistantMessage,
    CallConfirmation,
    ToolCard,
    SingleCallReceipt,
    BatchCallReceipt,
    EnvironmentPrecheck,
    OcrImage
}

sealed interface ConversationTimelinePayload {
    val kind: ConversationTimelineKind

    data class UserMessage(val text: String) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.UserMessage
    }

    data class AssistantMessage(val text: String) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.AssistantMessage
    }

    data class CallConfirmation(
        val callSpec: CallSpecPayload,
        val toolCallId: String? = null,
    ) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.CallConfirmation
    }

    data class ToolCard(
        val toolName: String,
        val summary: String = "",
        val status: String? = null
    ) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.ToolCard
    }

    data class SingleCallReceipt(
        val callAttemptId: String,
        val receipt: TaskReceiptItemState,
        val callId: String? = null,
        val phoneNumber: String = "",
        val createdAt: String? = null,
        val updatedAt: String? = null,
    ) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.SingleCallReceipt
    }

    data class BatchCallReceipt(
        val batchAttemptId: String,
        val receipt: BatchTaskReceiptState
    ) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.BatchCallReceipt
    }

    data class EnvironmentPrecheck(
        val summary: String,
        val passed: Boolean? = null
    ) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.EnvironmentPrecheck
    }

    data class OcrImage(
        val attachmentId: String,
        val contentPath: String,
        val contentType: String,
        val fileSize: Long,
        val anchorStepCount: Int,
        val createdOrdinal: Long,
        val fields: List<OcrField>,
        val segments: List<String>,
        val fullText: String,
    ) : ConversationTimelinePayload {
        override val kind = ConversationTimelineKind.OcrImage
    }

    data class OcrField(
        val label: String,
        val value: String,
    )
}
