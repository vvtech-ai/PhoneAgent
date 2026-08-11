package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamCallTranscriptPolicyTest {
    @Test
    fun callSpecTranscriptNotesFormatsFoodFields() {
        val notes = AgentStreamCallTranscriptPolicy.callSpecTranscriptNotes(
            CallSpecPayload(
                phoneNumber = "010-12345678",
                scene = "food",
                targetName = "北海渔村",
                primaryGoal = "订包间",
                summaryLines = listOf(
                    "partySize:4",
                    "needPrivateRoom:true",
                    "reservationTime:2026-06-11T18:30"
                )
            )
        ).map { it.text }

        assertTrue(notes.contains("通话任务字段：餐厅：北海渔村"))
        assertTrue(notes.contains("通话任务字段：电话：010-12345678"))
        assertTrue(notes.contains("通话任务字段：需求：订包间"))
        assertTrue(notes.contains("通话任务字段：人数：4人"))
        assertTrue(notes.contains("通话任务字段：包房：需要包房"))
        assertTrue(notes.contains("通话任务字段：时间：2026-06-11 18:30"))
    }

    @Test
    fun callSpecTranscriptNotesFormatsHotelFields() {
        val notes = AgentStreamCallTranscriptPolicy.callSpecTranscriptNotes(
            CallSpecPayload(
                phoneNumber = "400-0000",
                scene = "hotel_booking",
                targetName = "丽景酒店",
                primaryGoal = "订房",
                summaryLines = listOf("roomType:大床房", "guestCount:2")
            )
        ).map { it.text }

        assertTrue(notes.contains("通话任务字段：酒店：丽景酒店"))
        assertTrue(notes.contains("通话任务字段：房型：大床房"))
        assertTrue(notes.contains("通话任务字段：人数：2人"))
    }

    @Test
    fun callResultPageDataMergesDialogueAndBookingSummary() {
        val result = CallResultPayload(
            status = "COMPLETED",
            headline = "预订成功",
            detail = "assistant: 您好，请问有包间吗\ncallee: 已预留包间",
            metadata = mapOf("agentReason" to "包间已确认")
        )
        val pageData = AgentStreamCallTranscriptPolicy.callResultPageData(
            current = CallPageData(name = "北海渔村", sub = "", status = "拨打中", transcript = emptyList()),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "CALL_RESULT",
                text = null,
                callResult = result
            ),
            resultStatusText = "任务完成"
        )

        assertEquals("任务完成", pageData.status)
        assertSame(result, pageData.callResult)
        assertEquals(TranscriptRole.Assistant, pageData.transcript[0].role)
        assertEquals("您好，请问有包间吗", pageData.transcript[0].text)
        assertEquals(TranscriptRole.Remote, pageData.transcript[1].role)
        assertEquals("已预留包间", pageData.transcript[1].text)
        assertTrue(pageData.transcript.last().text.startsWith("预订结果：预订成功"))
        assertTrue(pageData.transcript.last().text.contains("包间已确认"))
    }

    @Test
    fun callResultPageDataParsesChineseDialogueSpeakers() {
        val pageData = AgentStreamCallTranscriptPolicy.callResultPageData(
            current = CallPageData(name = "新荣记", sub = "", status = "拨打中", transcript = emptyList()),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(
                    status = "COMPLETED",
                    headline = "新荣记已订好",
                    detail = "已成功预订明晚 18:00 新荣记新源南路店包房，8 位用餐。",
                    metadata = mapOf(
                        "dialogueTranscript" to "AI：你好，问一下明天晚上有包房吗？\n对方：请问几位用餐？"
                    )
                )
            ),
            resultStatusText = "任务完成"
        )

        assertEquals("任务完成", pageData.status)
        assertEquals(TranscriptRole.Assistant, pageData.transcript[0].role)
        assertEquals("你好，问一下明天晚上有包房吗？", pageData.transcript[0].text)
        assertEquals(TranscriptRole.Remote, pageData.transcript[1].role)
        assertEquals("请问几位用餐？", pageData.transcript[1].text)
        assertTrue(pageData.transcript.last().text.startsWith("预订结果：新荣记已订好"))
    }

    @Test
    fun callResultPageDataPreservesRepeatedDialogueOccurrences() {
        val repeatedRequest = "您的车占用了我的固定车位，麻烦您方便的话过来挪一下。"
        val repeatedClosing = "好的，打扰了。"
        val dialogue = listOf(
            "assistant: 您好，请问是车主吗？",
            "merchant: 是的。",
            "assistant: 我是帮现场车主联系挪车的。",
            "merchant: 谁说那是你的车位？",
            "assistant: $repeatedRequest",
            "merchant: 我。",
            "assistant: 麻烦",
            "merchant: 我交了停车费。",
            "assistant: $repeatedRequest",
            "merchant: 我凭什么？",
            "assistant: $repeatedRequest",
            "merchant: 这是我的车位。",
            "assistant: $repeatedRequest",
            "merchant: 我不挪。",
            "assistant: $repeatedClosing",
            "merchant: 知道了。",
            "assistant: $repeatedClosing",
            "merchant: 你挂电话吧。",
            "assistant: $repeatedClosing"
        ).joinToString("\n")

        val pageData = AgentStreamCallTranscriptPolicy.callResultPageData(
            current = CallPageData(name = "AI 外呼", sub = "", status = "拨打中", transcript = emptyList()),
            response = AgentChatResponse(
                sessionId = "bug-23131",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(
                    status = "FAILED",
                    headline = "挪车通知失败",
                    detail = "对方拒绝挪车",
                    metadata = mapOf("dialogueTranscript" to dialogue)
                )
            ),
            resultStatusText = "任务失败"
        )

        val dialogueLines = pageData.transcript.filter { it.role != TranscriptRole.Note }
        assertEquals(19, dialogueLines.size)
        assertEquals(4, dialogueLines.count { it.text == repeatedRequest })
        assertEquals(3, dialogueLines.count { it.text == repeatedClosing })
    }

    @Test
    fun callResultPageDataSkipsDialogueWhenLiveTranscriptExists() {
        val pageData = AgentStreamCallTranscriptPolicy.callResultPageData(
            current = CallPageData(
                name = "小明",
                sub = "",
                status = "拨打中",
                transcript = listOf(TranscriptLine(TranscriptRole.Assistant, "已有实时转写"))
            ),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "CALL_RESULT",
                text = null,
                callResult = CallResultPayload(
                    status = "COMPLETED",
                    headline = "已通知",
                    detail = "assistant: 新增助手对话\ncallee: 新增远端对话"
                )
            ),
            resultStatusText = "AI代打完成"
        )

        assertEquals("AI代打完成", pageData.status)
        assertTrue(pageData.transcript.any { it.text == "已有实时转写" })
        assertFalse(pageData.transcript.any { it.text == "新增助手对话" })
        assertFalse(pageData.transcript.any { it.text == "新增远端对话" })
        assertTrue(pageData.transcript.last().text.startsWith("AI代打结果：已通知"))
    }

    @Test
    fun resolveCallSpecSceneTypeFallsBackToCurrentScene() {
        assertEquals("FOOD_ORDERING", AgentStreamCallTranscriptPolicy.resolveCallSpecSceneType("restaurant", "AI_CALL"))
        assertEquals("HOTEL_BOOKING", AgentStreamCallTranscriptPolicy.resolveCallSpecSceneType("hotel", "AI_CALL"))
        assertEquals("AI_CALL", AgentStreamCallTranscriptPolicy.resolveCallSpecSceneType(null, ""))
        assertEquals("CUSTOM", AgentStreamCallTranscriptPolicy.resolveCallSpecSceneType(null, "CUSTOM"))
    }
}
