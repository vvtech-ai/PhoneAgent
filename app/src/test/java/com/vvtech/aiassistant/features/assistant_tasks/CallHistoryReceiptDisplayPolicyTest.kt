package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import org.junit.Assert.assertEquals
import org.junit.Test

class CallHistoryReceiptDisplayPolicyTest {
    @Test
    fun `generic terminal headline falls back to the business utterance`() {
        val summary = callHistoryReceiptSummary(
            resultReason = "目标号码 13800000000 已接通。 主叫号码为 01000000000。 电话脑摘要：好的，谢谢。",
            statusMessage = "AI 电话已结束",
            dialogueSummary = "AI 电话已结束",
            transcript = listOf(
                TranscriptLine(TranscriptRole.Assistant, "你好，请问是 13800000000 的机主吗？"),
                TranscriptLine(TranscriptRole.Remote, "是的。"),
                TranscriptLine(TranscriptRole.Assistant, "有个测试任务跟你说一下。"),
            ),
            success = true,
        )

        assertEquals("有个测试任务跟你说一下", summary)
    }

    @Test
    fun `structured business result keeps priority over transcript`() {
        val summary = callHistoryReceiptSummary(
            resultReason = "明晚 18:00 已预订 8 位",
            statusMessage = "通话已完成",
            dialogueSummary = null,
            transcript = listOf(TranscriptLine(TranscriptRole.Assistant, "想咨询包房。")),
            success = true,
        )

        assertEquals("明晚 18:00 已预订 8 位", summary)
    }

    @Test
    fun `assistant identity and phone are removed from list summary`() {
        val summary = callHistoryReceiptSummary(
            resultReason = null,
            statusMessage = "AI 电话已结束",
            dialogueSummary = null,
            transcript = listOf(
                TranscriptLine(TranscriptRole.Assistant, "又是我，之前打过的 Test。"),
                TranscriptLine(TranscriptRole.Assistant, "有个测试任务跟您说一下，我是 Test，电话是 13800138000。"),
            ),
            success = true,
        )

        assertEquals("有个测试任务跟您说一下", summary)
    }

    @Test
    fun `low information detail does not hide a later business utterance`() {
        val summary = callHistoryReceiptSummary(
            resultReason = "嗯，好。",
            statusMessage = "AI 电话已结束",
            dialogueSummary = null,
            transcript = listOf(
                TranscriptLine(TranscriptRole.Assistant, "嗯，好。"),
                TranscriptLine(TranscriptRole.Assistant, "提醒您明天提交测试结果。"),
            ),
            success = true,
        )

        assertEquals("提醒您明天提交测试结果", summary)
    }
}
