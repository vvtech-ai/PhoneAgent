package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.model.DefaultReservationContactPayload
import com.vvtech.aiassistant.model.DeviceContactPayload
import com.vvtech.aiassistant.model.UserContextPayload
import com.vvtech.aiassistant.model.UserCurrentTimePayload
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamCallResultHistoryPolicyTest {
    @Test
    fun batchCallHistoryEntriesMapEachRecipientToSameParentTask() {
        val entries = AgentStreamBatchCallHistoryPolicy.localHistoryEntries(
            AgentStreamBatchCallResultHistoryInput(
                sessionId = " parent-session ",
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "批量外呼完成",
                    items = listOf(
                        batchItem(
                            itemId = "recipient-1",
                            targetName = "老九",
                            phoneNumber = "13800138000",
                            status = "SUCCESS",
                            headline = "对方已确认参加",
                            detail = "老九确认参加",
                            transcript = "assistant: 明天下午三点开会\ncallee: 好的，我会参加"
                        ),
                        batchItem(
                            itemId = "recipient-2",
                            targetName = "小米",
                            phoneNumber = "13800138001",
                            status = "FAILED",
                            headline = "未接通",
                            detail = "无人接听",
                            transcript = "无人接听"
                        )
                    )
                ),
                resultStatusText = "任务已完成"
            )
        )

        assertEquals(2, entries.size)
        assertEquals(listOf("parent-session", "parent-session"), entries.map { it.taskId })
        assertTrue(entries[0].callId.startsWith("batch:"))
        assertTrue(entries[0].callId.endsWith(":recipient-1"))
        assertTrue(entries[1].callId.startsWith("batch:"))
        assertTrue(entries[1].callId.endsWith(":recipient-2"))
        assertNotEquals(entries[0].callId, entries[1].callId)
        assertEquals(listOf("老九", "小米"), entries.map { it.title })
        assertEquals(listOf("13800138000", "13800138001"), entries.map { it.phoneNumber })
        assertEquals(StatusStyle.Success, entries[0].style)
        assertEquals(StatusStyle.Failure, entries[1].style)
        assertEquals(listOf("明天下午三点开会", "好的，我会参加"), entries[0].transcript.map { it.text })
        assertEquals(listOf("无人接听"), entries[1].transcript.map { it.text })
    }

    @Test
    fun repeatedBatchCallUnderSameTaskKeepsSeparateHistoryWhenContentChanges() {
        val firstEntries = AgentStreamBatchCallHistoryPolicy.localHistoryEntries(
            AgentStreamBatchCallResultHistoryInput(
                sessionId = "meeting-task",
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "会议邀请已完成",
                    items = listOf(
                        batchItem(
                            itemId = "person-1",
                            targetName = "老九",
                            phoneNumber = "13800138000",
                            status = "SUCCESS",
                            headline = "已确认参会",
                            detail = "老九确认明天下午三点参加",
                            transcript = "assistant: 明天下午三点开会\ncallee: 好的，三点参加"
                        )
                    )
                ),
                resultStatusText = "任务已完成"
            )
        )
        val secondEntries = AgentStreamBatchCallHistoryPolicy.localHistoryEntries(
            AgentStreamBatchCallResultHistoryInput(
                sessionId = "meeting-task",
                batchCallResult = BatchCallResultPayload(
                    status = "COMPLETED",
                    headline = "会议邀请已完成",
                    items = listOf(
                        batchItem(
                            itemId = "person-1",
                            targetName = "老九",
                            phoneNumber = "13800138000",
                            status = "SUCCESS",
                            headline = "已确认参会",
                            detail = "老九确认改到明天下午四点参加",
                            transcript = "assistant: 会议时间改到明天下午四点\ncallee: 好的，四点参加"
                        )
                    )
                ),
                resultStatusText = "任务已完成"
            )
        )

        assertEquals("meeting-task", firstEntries.single().taskId)
        assertEquals("meeting-task", secondEntries.single().taskId)
        assertTrue(firstEntries.single().callId.endsWith(":person-1"))
        assertTrue(secondEntries.single().callId.endsWith(":person-1"))
        assertNotEquals(firstEntries.single().callId, secondEntries.single().callId)
    }

    @Test
    fun localHistoryEntryReturnsNullForBlankSession() {
        val entry = AgentStreamCallResultHistoryPolicy.localHistoryEntry(
            sessionId = "  ",
            currentCallPage = CallPageData(name = "北海渔村", sub = "", status = "", transcript = emptyList()),
            callResult = null,
            resultStatusText = "AI代打完成",
            resolvedConversationStatus = "COMPLETED"
        )

        assertNull(entry)
    }

    @Test
    fun localHistoryEntryBuildsCompletedEntryAndDeduplicatesDetails() {
        val entry = AgentStreamCallResultHistoryPolicy.localHistoryEntry(
            sessionId = " session-1 ",
            currentCallPage = CallPageData(name = "北海渔村", sub = "", status = "", transcript = emptyList()),
            callResult = CallResultPayload(
                status = "COMPLETED",
                headline = "预订成功",
                detail = "包间已预留",
                metadata = mapOf(
                    "callId" to "call-1",
                    "agentReason" to "包间已预留",
                    "resultReason" to "已确认今晚到店"
                )
            ),
            resultStatusText = "任务完成",
            resolvedConversationStatus = "COMPLETED"
        )

        requireNotNull(entry)
        assertEquals("session-1", entry.taskId)
        assertEquals("call-1", entry.callId)
        assertEquals("北海渔村", entry.title)
        assertEquals("任务完成", entry.status)
        assertEquals(StatusStyle.Success, entry.style)
        assertEquals("包间已预留\n已确认今晚到店", entry.metaDetail)
        assertTrue(entry.finalState)
    }

    @Test
    fun localHistoryEntryFallsBackTitleMetaDetailAndFailureStyle() {
        val entry = AgentStreamCallResultHistoryPolicy.localHistoryEntry(
            sessionId = "session-2",
            currentCallPage = CallPageData(name = "", sub = "", status = "", transcript = emptyList()),
            callResult = CallResultPayload(
                status = "FAILED",
                headline = "未接通",
                detail = " ",
                metadata = emptyMap()
            ),
            resultStatusText = "AI代打失败",
            resolvedConversationStatus = "FAILED"
        )

        requireNotNull(entry)
        assertEquals("未接通", entry.title)
        assertEquals(StatusStyle.Failure, entry.style)
        assertEquals("AI代打失败", entry.metaDetail)
    }

    @Test
    fun agentContextLogMessageFormatsCoordinatesAndMasksPhones() {
        val message = AgentStreamCallResultHistoryPolicy.agentContextLogMessage(
            action = "chat_stream",
            sessionId = "session-1",
            voice = true,
            context = UserContextPayload(
                city = "北京",
                district = "朝阳区",
                adcode = "110105",
                lat = 39.9042,
                lng = 116.4074,
                defaultReservationContact = DefaultReservationContactPayload(
                    name = "张三",
                    phone = "18812345678"
                ),
                currentTime = UserCurrentTimePayload(
                    isoDateTime = "2026-06-11T18:30:00",
                    timezone = "Asia/Shanghai"
                ),
                deviceContacts = listOf(
                    DeviceContactPayload(contactName = "小明", phoneNumber = "13800138000", status = "FOUND")
                )
            )
        )

        assertTrue(message.contains("action=chat_stream session=session-1 voice=true"))
        assertTrue(message.contains("latPresent=true lngPresent=true"))
        assertTrue(message.contains("lat=39.904200 lng=116.407400"))
        assertTrue(message.contains("adcode=110105 city=北京 district=朝阳区"))
        assertTrue(message.contains("time=2026-06-11T18:30:00 timezone=Asia/Shanghai"))
        assertTrue(message.contains("contactPresent=true contactName=张三 contactPhoneLast4=5678"))
        assertTrue(message.contains("deviceContacts=1 deviceContactSummary=小明:FOUND:8000"))
        assertFalse(message.contains("18812345678"))
        assertFalse(message.contains("13800138000"))
    }

    @Test
    fun applyCallResultLogMessageIncludesOutcomeAndMetadata() {
        val message = AgentStreamCallResultHistoryPolicy.applyCallResultLogMessage(
            responseSessionId = "response-session",
            currentSessionId = "current-session",
            callResult = CallResultPayload(
                status = "COMPLETED",
                headline = "预订成功",
                detail = "已订包间",
                metadata = linkedMapOf(
                    "agentOutcome" to "SUCCESS",
                    "resultCode" to "BOOKED",
                    "resultReason" to "包间已确认",
                    "agentReason" to "商家确认预留",
                    "callId" to "call-1",
                    "taskId" to "task-1"
                )
            ),
            resolvedConversationStatus = "COMPLETED",
            resultStatusText = "任务完成"
        )

        assertTrue(message.contains("Apply CALL_RESULT responseSessionId=response-session"))
        assertTrue(message.contains("currentSessionId=current-session"))
        assertTrue(message.contains("status=COMPLETED"))
        assertTrue(message.contains("agentOutcome=SUCCESS"))
        assertTrue(message.contains("resultCode=BOOKED"))
        assertTrue(message.contains("resultReason=包间已确认"))
        assertTrue(message.contains("agentReason=商家确认预留"))
        assertTrue(message.contains("callId=call-1"))
        assertTrue(message.contains("taskId=task-1"))
        assertTrue(message.contains("resolvedTaskStatus=COMPLETED"))
        assertTrue(message.contains("statusText=任务完成"))
        assertTrue(message.contains("metadataKeys=agentOutcome,resultCode,resultReason,agentReason,callId,taskId"))
    }

    private fun batchItem(
        itemId: String,
        targetName: String,
        phoneNumber: String,
        status: String,
        headline: String,
        detail: String,
        transcript: String? = null
    ): BatchCallItemResultPayload {
        return BatchCallItemResultPayload(
            itemId = itemId,
            targetName = targetName,
            phoneNumber = phoneNumber,
            status = status,
            headline = headline,
            detail = detail,
            attemptCount = 1,
            recalled = false,
            abnormal = status.equals("FAILED", ignoreCase = true),
            transcript = transcript
        )
    }
}
