package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload

internal object PureVoiceOcrHistoryProjection {
    fun project(
        items: List<ConversationTimelineItem>,
        sessionId: String,
    ): List<PureVoiceOcrHistoryAttachment> {
        val byAttachmentId = linkedMapOf<String, PureVoiceOcrHistoryAttachment>()
        items.sortedWith(
            compareBy<ConversationTimelineItem> { it.ledgerSequence ?: Long.MAX_VALUE }
                .thenBy { it.orderKey }
                .thenBy { it.itemId }
        ).forEach { item ->
            if (item.sessionId != sessionId) return@forEach
            val payload = item.payload as? ConversationTimelinePayload.OcrImage
            if (payload == null) return@forEach
            byAttachmentId[payload.attachmentId] = PureVoiceOcrHistoryAttachment(
                sessionId = sessionId,
                attachmentId = payload.attachmentId,
                contentPath = payload.contentPath,
                contentType = payload.contentType,
                // The attachment was selected before its asynchronous commit completed.
                // Preserve that selection-time boundary instead of deriving from Ledger order.
                anchorStepCount = payload.anchorStepCount,
                createdOrdinal = payload.createdOrdinal,
                fields = payload.fields.mapIndexed { index, field ->
                    PureVoiceOcrField(
                        key = "${payload.attachmentId}:field:$index",
                        label = field.label,
                        value = field.value,
                    )
                },
                segments = payload.segments,
                fullText = payload.fullText,
            )
        }
        return PureVoiceOcrDisplayOrdering.ordered(byAttachmentId.values.toList())
    }
}
