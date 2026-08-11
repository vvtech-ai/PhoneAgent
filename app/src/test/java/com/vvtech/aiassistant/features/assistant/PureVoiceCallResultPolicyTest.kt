package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PureVoiceCallResultPolicyTest {
    @Test
    fun bookingRowsIgnoreShellPlaceholdersForGenericAiCallResult() {
        val rows = pureVoiceBookingRows(
            sceneType = "AI_CALL",
            summary = null,
            data = CallPageData(
                name = "AI助理",
                sub = "实时外呼",
                status = "AI代打完成",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Assistant, "八个人。"),
                    TranscriptLine(TranscriptRole.Assistant, "有没有包房？"),
                    TranscriptLine(TranscriptRole.Remote, "嗯，有包房。"),
                    TranscriptLine(TranscriptRole.Assistant, "那可以帮我预订吗？"),
                    TranscriptLine(TranscriptRole.Remote, "可以。"),
                    TranscriptLine(TranscriptRole.Assistant, "手机号呢？"),
                    TranscriptLine(TranscriptRole.Remote, "手机号是18813228645。")
                )
            )
        )

        assertFalse(rows.contains("餐厅" to "AI助理"))
        assertFalse(rows.contains("目的" to "实时外呼"))
        assertTrue(rows.contains("包房" to "有"))
        assertTrue(rows.contains("联系人" to "18813228645"))
        assertEquals("八人", rows.first { it.first == "人数" }.second)
    }
}
