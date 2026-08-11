package com.vvtech.aiassistant.features.assistant_timeline

import com.google.gson.JsonParser
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OcrImageTimelineProjectionTest {
    @Test
    fun committedOcrEventRestoresCloudImageAndCapturedUiOrder() {
        val event = ConversationLedgerEvent(
            eventId = "event-ocr-1",
            sessionId = "session-1",
            sequence = 9,
            type = ConversationLedgerEventType.Known(
                StableConversationLedgerEventType.OCR_IMAGE_COMMITTED
            ),
            schemaVersion = 1,
            idempotencyKey = "ocr-1",
            occurredAt = "2026-07-24T10:00:00Z",
            committedAt = "2026-07-24T10:00:01Z",
            payload = JsonParser().parse(
                """
                {
                  "attachmentId":"ocr-image-1",
                  "contentPath":"/api/agent/conversations/session-1/attachments/ocr-image-1/content",
                  "contentType":"image/png",
                  "fileSize":128,
                  "anchorStepCount":2,
                  "createdOrdinal":3,
                  "fields":[{"label":"姓名","value":"张三"}],
                  "segments":["姓名 张三"],
                  "fullText":"姓名 张三"
                }
                """.trimIndent()
            ).asJsonObject,
        )

        val rendered = ConversationLedgerTimelineMapper.map(event) as LedgerTimelineMapping.Rendered
        val item = (rendered.event as ConversationTimelineEvent.Upsert).item
        val payload = item.payload as ConversationTimelinePayload.OcrImage

        assertEquals("ocr-image-1", payload.attachmentId)
        assertEquals(2, payload.anchorStepCount)
        assertEquals(3L, payload.createdOrdinal)
        assertEquals("张三", payload.fields.single().value)
        assertTrue(ConversationTimelineToClarificationStepsAdapter.adapt(listOf(item)).isEmpty())
    }
}
