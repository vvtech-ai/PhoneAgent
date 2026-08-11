package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import org.junit.Assert.assertEquals
import org.junit.Test

class PureVoiceOcrHistoryProjectionTest {
    @Test
    fun historyRestoresPersistedAnchorBetweenOpeningAndLaterUserTurn() {
        val opening = assistantMessageItem(
            eventId = "event-opening",
            sequence = 1,
            text = "欢迎使用图片识别",
        )
        val image = item(
            eventId = "event-image",
            sequence = 2,
            attachmentId = "ocr-image",
            anchorStepCount = 1,
            createdOrdinal = 0,
        )
        val laterUserMessage = messageItem(
            eventId = "event-user",
            sequence = 3,
            text = "这是张三的号码",
        )

        val restored = PureVoiceOcrHistoryProjection.project(
            listOf(laterUserMessage, image, opening),
            sessionId = "session-1",
        )
        val byAnchor = PureVoiceOcrDisplayOrdering.byAnchor(restored, displayStepCount = 2)
        val visualOrder = buildList {
            byAnchor[0].orEmpty().forEach { add(it.attachmentId) }
            add("opening")
            byAnchor[1].orEmpty().forEach { add(it.attachmentId) }
            add("user-message")
            byAnchor[2].orEmpty().forEach { add(it.attachmentId) }
        }

        assertEquals(listOf("opening", "ocr-image", "user-message"), visualOrder)
        assertEquals(1, restored.single().anchorStepCount)
    }

    @Test
    fun historyPreservesSelectionAnchorsInsteadOfDerivingFromCommitSequence() {
        val restored = PureVoiceOcrHistoryProjection.project(
            listOf(
                messageItem("event-user-1", 1, "第一条"),
                item("event-image-1", 4, "ocr-image-1", 1, 0),
                messageItem("event-user-2", 3, "第二条"),
                item("event-image-2", 2, "ocr-image-2", 2, 1),
            ),
            sessionId = "session-1",
        )

        assertEquals(listOf(1, 2), restored.map { it.anchorStepCount })
        assertEquals(listOf(0L, 1L), restored.map { it.createdOrdinal })
    }

    @Test
    fun historyProjectionNeverRestoresAnotherSession() {
        val restored = PureVoiceOcrHistoryProjection.project(
            listOf(
                item(
                    eventId = "event-old-session",
                    sequence = 1,
                    attachmentId = "ocr-old-session",
                    anchorStepCount = 0,
                    createdOrdinal = 0,
                    sessionId = "session-old",
                ),
                item(
                    eventId = "event-current-session",
                    sequence = 2,
                    attachmentId = "ocr-current-session",
                    anchorStepCount = 0,
                    createdOrdinal = 0,
                    sessionId = "session-current",
                ),
            ),
            sessionId = "session-current",
        )

        assertEquals(listOf("ocr-current-session"), restored.map { it.attachmentId })
    }

    private fun item(
        eventId: String,
        sequence: Long,
        attachmentId: String,
        anchorStepCount: Int,
        createdOrdinal: Long,
        sessionId: String = "session-1",
    ) = ConversationTimelineItem(
        itemId = "ledger:$eventId",
        sessionId = sessionId,
        orderKey = TimelineOrderKey(0),
        ledgerSequence = sequence,
        ledgerEventId = eventId,
        payload = ConversationTimelinePayload.OcrImage(
            attachmentId = attachmentId,
            contentPath = "/content/$attachmentId",
            contentType = "image/png",
            fileSize = 100,
            anchorStepCount = anchorStepCount,
            createdOrdinal = createdOrdinal,
            fields = listOf(ConversationTimelinePayload.OcrField("姓名", "张三")),
            segments = listOf("张三"),
            fullText = "张三",
        ),
    )

    private fun messageItem(
        eventId: String,
        sequence: Long,
        text: String,
        sessionId: String = "session-1",
    ) = ConversationTimelineItem(
        itemId = "ledger:$eventId",
        sessionId = sessionId,
        orderKey = TimelineOrderKey(0),
        ledgerSequence = sequence,
        ledgerEventId = eventId,
        payload = ConversationTimelinePayload.UserMessage(text),
    )

    private fun assistantMessageItem(
        eventId: String,
        sequence: Long,
        text: String,
        sessionId: String = "session-1",
    ) = ConversationTimelineItem(
        itemId = "ledger:$eventId",
        sessionId = sessionId,
        orderKey = TimelineOrderKey(0),
        ledgerSequence = sequence,
        ledgerEventId = eventId,
        payload = ConversationTimelinePayload.AssistantMessage(text),
    )
}
