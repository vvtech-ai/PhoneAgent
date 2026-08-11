package com.vvtech.aiassistant.features.assistant_timeline

import com.google.gson.JsonParser
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.domain.task.ReceiptField
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationLedgerTimelineMapperTest {
    @Test
    fun supportedEventUsesDurableLongSequenceAndEventId() {
        val event = event(sequence = Long.MAX_VALUE, type = StableConversationLedgerEventType.USER_TURN_ACCEPTED)

        val mapped = ConversationLedgerTimelineMapper.map(event) as LedgerTimelineMapping.Rendered
        val state = ConversationLedgerTimelineReducer.reduce(LedgerTimelineState(), mapped)

        assertEquals(Long.MAX_VALUE, state.cursor)
        assertEquals("event-1", state.items.single().ledgerEventId)
        assertEquals(Long.MAX_VALUE, state.items.single().ledgerSequence)
    }

    @Test
    fun unknownVersionAdvancesCursorWithoutInventingTimelineItem() {
        val event = event(sequence = 9L, type = StableConversationLedgerEventType.CALL_COMPLETED).copy(schemaVersion = 2)

        val mapped = ConversationLedgerTimelineMapper.map(event)
        val state = ConversationLedgerTimelineReducer.reduce(LedgerTimelineState(), mapped)

        assertTrue(mapped is LedgerTimelineMapping.Skipped)
        assertEquals(9L, state.cursor)
        assertTrue(state.items.isEmpty())
    }

    @Test
    fun unknownEventTypeAdvancesCursorWithoutInventingTimelineItem() {
        val event = event(sequence = 10L, type = StableConversationLedgerEventType.USER_TURN_ACCEPTED).copy(
            type = ConversationLedgerEventType.Unknown("FUTURE_SERVER_EVENT"),
        )

        val mapped = ConversationLedgerTimelineMapper.map(event)
        val state = ConversationLedgerTimelineReducer.reduce(LedgerTimelineState(), mapped)

        assertTrue(mapped is LedgerTimelineMapping.Skipped)
        assertEquals("unknown_event_type", (mapped as LedgerTimelineMapping.Skipped).reason)
        assertEquals(10L, state.cursor)
        assertTrue(state.items.isEmpty())
    }

    @Test
    fun makeCallToolRequestProjectsReadOnlyConfirmationCard() {
        val requested = event(1L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            payload = JsonParser().parse(
                """{"toolCallId":"tool-call-1","toolName":"makeCall","arguments":{"phoneNumber":"13800138000","scene":"restaurant_booking","targetName":"海底捞","primaryGoal":"今晚八点订四人位","summaryLines":["partySize：4","privateRoom：true"]}}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(listOf(requested))
        val confirmation = state.items.single().payload as ConversationTimelinePayload.CallConfirmation
        val step = ConversationTimelineToClarificationStepsAdapter.adapt(state.items).single()

        assertEquals("海底捞", confirmation.callSpec.targetName)
        assertEquals(listOf("partySize：4", "privateRoom：true"), confirmation.callSpec.summaryLines)
        assertEquals("tool-call-1", confirmation.toolCallId)
        assertEquals(confirmation.callSpec, step.callConfirmSpec)
        assertEquals("tool-call-1", step.callConfirmIdentity)
        assertEquals("任务确认完毕，现在帮您拨打海底捞的电话...", step.text)
        assertEquals(1L, state.cursor)
    }

    @Test
    fun policyRejectedMakeCallDoesNotRemainAsConfirmationCard() {
        val rejectedRequest = event(1L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            eventId = "rejected-request",
            payload = JsonParser().parse(
                """{"toolCallId":"rejected-call","toolName":"makeCall","arguments":{"phoneNumber":"13800138000","scene":"restaurant_booking","targetName":"门店A","primaryGoal":"预订包房"}}"""
            ).asJsonObject,
        )
        val rejectedResult = event(2L, StableConversationLedgerEventType.TOOL_RESULT_RECORDED).copy(
            eventId = "rejected-result",
            payload = JsonParser().parse(
                """{"toolCallId":"rejected-call","toolName":"makeCall","result":{"text":"请先确认其他要求"},"resultStatus":"policy_rejected"}"""
            ).asJsonObject,
        )
        val acceptedRequest = event(3L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            eventId = "accepted-request",
            payload = JsonParser().parse(
                """{"toolCallId":"accepted-call","toolName":"makeCall","arguments":{"phoneNumber":"13800138001","scene":"restaurant_booking","targetName":"门店B","primaryGoal":"预订包房"}}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(
            listOf(rejectedRequest, rejectedResult, acceptedRequest)
        )
        val confirmation = state.items.single().payload as ConversationTimelinePayload.CallConfirmation

        assertEquals("accepted-call", confirmation.toolCallId)
        assertEquals("门店B", confirmation.callSpec.targetName)
        assertEquals(3L, state.cursor)
    }

    @Test
    fun showOptionsRequestProjectsUserVisibleAssistantResultCard() {
        val requested = event(1L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            payload = JsonParser().parse(
                """
                {
                  "toolName":"showOptions",
                  "displayPayloadVersion":1,
                  "arguments":{
                    "title":"搜到的结果",
                    "optionsJson":[
                      {
                        "id":"restaurant-1",
                        "label":"测试餐厅",
                        "detail":"新店",
                        "phone":"020-12345678",
                        "address":"测试路1号",
                        "distanceMeters":800
                      }
                    ]
                  }
                }
                """.trimIndent()
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(listOf(requested))
        val message = state.items.single().payload as ConversationTimelinePayload.AssistantMessage

        assertEquals(
            "搜到的结果\n1. 测试餐厅 (新店 | 020-12345678 | 测试路1号 | 800m)",
            message.text,
        )
    }

    @Test
    fun interactiveToolRequestsProjectRealtimeEquivalentAssistantPrompts() {
        val askUser = event(1L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            payload = JsonParser().parse(
                """
                {
                  "toolName":"askUser",
                  "displayPayloadVersion":1,
                  "arguments":{
                    "title":"再确认两件事",
                    "questionsJson":[
                      {"prompt":"几点出发？"},
                      {"prompt":"从哪里出发？"}
                    ]
                  }
                }
                """.trimIndent()
            ).asJsonObject,
        )
        val permission = event(2L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            eventId = "event-2",
            payload = JsonParser().parse(
                """{"toolName":"requestPermission","displayPayloadVersion":1,"arguments":{"reason":"需要位置权限来查找附近餐厅"}}"""
            ).asJsonObject,
        )
        val document = event(3L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            eventId = "event-3",
            payload = JsonParser().parse(
                """{"toolName":"importDocument","displayPayloadVersion":1,"arguments":{"title":"上传行程","reason":"请上传行程文档"}}"""
            ).asJsonObject,
        )

        val messages = ConversationLedgerTimelineReducer.reduceAll(listOf(askUser, permission, document))
            .items
            .map { (it.payload as ConversationTimelinePayload.AssistantMessage).text }

        assertEquals(
            listOf(
                "再确认两件事\n· 几点出发？\n· 从哪里出发？",
                "需要位置权限来查找附近餐厅",
                "请上传行程文档",
            ),
            messages,
        )
    }

    @Test
    fun internalToolPayloadNeverBecomesUserVisibleTimelineText() {
        val secretMarker = "INTERNAL_SKILL_PROMPT_MUST_NOT_RENDER"
        val requested = event(1L, StableConversationLedgerEventType.TOOL_REQUESTED).copy(
            payload = JsonParser().parse(
                """{"toolName":"activateSkill","arguments":{"prompt":"$secretMarker"}}"""
            ).asJsonObject,
        )
        val result = event(2L, StableConversationLedgerEventType.TOOL_RESULT_RECORDED).copy(
            eventId = "event-2",
            payload = JsonParser().parse(
                """{"toolName":"activateSkill","result":{"text":"$secretMarker"},"resultStatus":"completed"}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(listOf(requested, result))
        assertTrue(state.items.isEmpty())
        assertFalse(state.items.toString().contains(secretMarker))
    }

    @Test
    fun internalFailureFactAdvancesCursorWithoutRenderingSuccessLookingToolCard() {
        val failure = event(3L, StableConversationLedgerEventType.RUN_FAILED).copy(
            payload = JsonParser().parse(
                """{"reason":"InvalidRequestException","stage":"model"}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(listOf(failure))

        assertTrue(state.items.isEmpty())
        assertEquals(3L, state.cursor)
    }

    @Test
    fun callAttemptCorrelatesRequestPhysicalTerminalToolResultAndSemanticOutcome() {
        val common = event(1L, StableConversationLedgerEventType.CALL_REQUESTED).copy(
            taskId = "task-1",
            callAttemptId = "attempt-1",
            callId = "call-1",
            payload = JsonParser().parse("""{"provider":"embedded","recipientRef":"phone-token"}""").asJsonObject,
        )
        val toolRequest = common.copy(
            eventId = "event-2", sequence = 2L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.TOOL_REQUESTED),
            payload = JsonParser().parse(
                """{"toolName":"makeCall","arguments":{"targetName":"王先生"}}"""
            ).asJsonObject,
        )
        val terminal = common.copy(
            eventId = "event-3", sequence = 3L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.CALL_COMPLETED),
            payload = JsonParser().parse("""{"provider":"embedded","resultCode":"COMPLETED"}""").asJsonObject,
        )
        val toolResult = common.copy(
            eventId = "event-4", sequence = 4L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.TOOL_RESULT_RECORDED),
            payload = JsonParser().parse(
                """{"toolName":"makeCall","result":{"status":"COMPLETED","headline":"已接通","detail":"物理详情","metadata":{"dialogueTranscript":"AI：您好\n对方：你好"}},"resultStatus":"RECORDED"}"""
            ).asJsonObject,
        )
        val outcome = common.copy(
            eventId = "event-5", sequence = 5L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.CALL_OUTCOME_REPORTED),
            payload = JsonParser().parse(
                """{"outcome":"SUCCESS","headline":"预约成功","reason":"已确认时间","receiptFields":[{"key":"taskType","label":"任务","value":"餐厅预订"},{"key":"restaurantName","label":"餐厅","value":"海底捞"},{"key":"partySize","label":"人数","value":"4 人"},{"key":"reservationTime","label":"时间","value":"今晚 8 点"},{"key":"parking","label":"停车","value":"商场 B2"}]}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(
            listOf(common, toolRequest, terminal, toolResult, outcome)
        )
        val callItem = state.items.single { it.payload is ConversationTimelinePayload.SingleCallReceipt }
        val payload = callItem.payload as ConversationTimelinePayload.SingleCallReceipt

        assertEquals("ledger:call:attempt-1", callItem.itemId)
        assertEquals(1L, callItem.ledgerSequence)
        assertEquals("event-5", callItem.ledgerEventId)
        assertEquals("attempt-1", payload.callAttemptId)
        assertEquals("COMPLETED", payload.receipt.status)
        assertEquals("王先生", payload.receipt.targetName)
        assertEquals("预约成功", payload.receipt.headline)
        assertEquals("已确认时间", payload.receipt.detail)
        assertEquals("AI：您好\n对方：你好", payload.receipt.transcript)
        assertEquals(
            listOf(
                ReceiptField("taskType", "任务", "餐厅预订"),
                ReceiptField("restaurantName", "餐厅", "海底捞"),
                ReceiptField("partySize", "人数", "4 人"),
                ReceiptField("reservationTime", "时间", "今晚 8 点"),
                ReceiptField("parking", "停车", "商场 B2"),
            ),
            payload.receipt.receiptFields,
        )
    }

    @Test
    fun failedSemanticOutcomeKeepsProvidedBaseFieldsWithoutInventingOptionalRows() {
        val requested = event(1L, StableConversationLedgerEventType.CALL_REQUESTED).copy(
            callAttemptId = "attempt-failed",
            payload = JsonParser().parse("""{"recipientRef":"restaurant"}""").asJsonObject,
        )
        val failed = requested.copy(
            eventId = "event-2",
            sequence = 2L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.CALL_OUTCOME_REPORTED),
            payload = JsonParser().parse(
                """{"outcome":"FAILED","headline":"预订失败","reason":"满位","receiptFields":[{"key":"taskType","label":"任务","value":"餐厅预订"},{"key":"restaurantName","label":"餐厅","value":"海底捞"},{"key":"partySize","label":"人数","value":"4 人"},{"key":"reservationTime","label":"时间","value":"今晚 8 点"}]}"""
            ).asJsonObject,
        )

        val receipt = (ConversationLedgerTimelineReducer.reduceAll(listOf(requested, failed))
            .items.single().payload as ConversationTimelinePayload.SingleCallReceipt).receipt

        assertEquals("FAILED", receipt.status)
        assertEquals(listOf("taskType", "restaurantName", "partySize", "reservationTime"), receipt.receiptFields.map { it.key })
    }

    @Test
    fun legacySemanticOutcomeWithoutFieldsRestoresAnEmptyList() {
        val requested = event(1L, StableConversationLedgerEventType.CALL_REQUESTED).copy(
            callAttemptId = "attempt-legacy",
            payload = JsonParser().parse("""{"recipientRef":"legacy"}""").asJsonObject,
        )
        val outcome = requested.copy(
            eventId = "event-2",
            sequence = 2L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.CALL_OUTCOME_REPORTED),
            payload = JsonParser().parse(
                """{"outcome":"SUCCESS","headline":"完成","reason":"旧回执"}"""
            ).asJsonObject,
        )

        val receipt = (ConversationLedgerTimelineReducer.reduceAll(listOf(requested, outcome))
            .items.single().payload as ConversationTimelinePayload.SingleCallReceipt).receipt

        assertTrue(receipt.receiptFields.isEmpty())
    }

    @Test
    fun sameTaskKeepsFourCallAttemptsAndRequestOnlyAttemptRemainsPending() {
        val events = (1L..4L).map { sequence ->
            event(sequence, StableConversationLedgerEventType.CALL_REQUESTED).copy(
                eventId = "event-$sequence",
                taskId = "task-1",
                callAttemptId = "attempt-$sequence",
                payload = JsonParser().parse(
                    """{"provider":"embedded","recipientRef":"target-$sequence"}"""
                ).asJsonObject,
            )
        }

        val state = ConversationLedgerTimelineReducer.reduceAll(events)
        val attempts = state.items.mapNotNull {
            (it.payload as? ConversationTimelinePayload.SingleCallReceipt)?.callAttemptId
        }

        assertEquals(listOf("attempt-1", "attempt-2", "attempt-3", "attempt-4"), attempts)
        val pending = state.items.first().payload as ConversationTimelinePayload.SingleCallReceipt
        assertEquals("CALL_REQUESTED", pending.receipt.status)
        assertFalse(pending.receipt.status == "COMPLETED")
    }

    @Test
    fun explicitBatchToolResultRestoresOneBatchReceiptWithoutInferringFromTaskId() {
        val calls = (1L..2L).map { sequence ->
            event(sequence, StableConversationLedgerEventType.CALL_REQUESTED).copy(
                eventId = "call-$sequence",
                taskId = "batch-1",
                callAttemptId = "attempt-$sequence",
                payload = JsonParser().parse(
                    """{"provider":"embedded","recipientRef":"target-$sequence"}"""
                ).asJsonObject,
            )
        }
        val batch = event(3L, StableConversationLedgerEventType.TOOL_RESULT_RECORDED).copy(
            eventId = "batch-result",
            payload = JsonParser().parse(
                """{"modelTurnId":"turn","toolCallId":"tool-batch","toolName":"makeBatchCalls","ordinal":0,"resultStatus":"completed","result":{"batchCallResult":{"batchId":"batch-1","status":"INCOMPLETE","headline":"批量外呼完成","items":[{"itemId":"one","targetName":"甲","status":"SUCCESS","headline":"完成","detail":"已确认","attemptCount":1,"recalled":false,"abnormal":false,"transcript":"甲转写"},{"itemId":"two","targetName":"乙","status":"NEEDS_RECALL","headline":"待确认","detail":"需要回拨","attemptCount":2,"recalled":true,"abnormal":true,"transcript":"乙转写"}]}}}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(calls + batch)
        val receipt = state.items.single().payload as ConversationTimelinePayload.BatchCallReceipt

        assertEquals("batch-1", receipt.batchAttemptId)
        assertEquals(listOf("甲", "乙"), receipt.receipt.items.map { it.targetName })
        assertEquals(2, receipt.receipt.items.last().attemptCount)
        assertTrue(receipt.receipt.items.last().recalled)
    }

    @Test
    fun repeatedTerminalCallbackIdentityKeepsOneCallAttemptItem() {
        val requested = event(1L, StableConversationLedgerEventType.CALL_REQUESTED).copy(
            taskId = "task-1",
            callAttemptId = "attempt-1",
            payload = JsonParser().parse("""{"recipientRef":"目标"}""").asJsonObject,
        )
        val terminal = requested.copy(
            eventId = "event-2",
            sequence = 2L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.CALL_COMPLETED),
            payload = JsonParser().parse("""{"resultCode":"COMPLETED","transcript":"唯一转写"}""").asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(listOf(requested, terminal, terminal))
        val receipts = state.items.mapNotNull { it.payload as? ConversationTimelinePayload.SingleCallReceipt }

        assertEquals(1, receipts.size)
        assertEquals("attempt-1", receipts.single().callAttemptId)
        assertEquals("唯一转写", receipts.single().receipt.transcript)
    }

    @Test
    fun physicalCompletionDoesNotConfuseBusinessResultCodeWithCallLifecycle() {
        val requested = event(1L, StableConversationLedgerEventType.CALL_REQUESTED).copy(
            taskId = "task-1",
            callAttemptId = "attempt-1",
            payload = JsonParser().parse("""{"recipientRef":"目标"}""").asJsonObject,
        )
        val terminal = requested.copy(
            eventId = "event-2",
            sequence = 2L,
            type = ConversationLedgerEventType.Known(StableConversationLedgerEventType.CALL_COMPLETED),
            payload = JsonParser().parse("""{"resultCode":"SUCCESS_CONFIRMED"}""").asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(listOf(requested, terminal))
        val receipt = state.items.single().payload as ConversationTimelinePayload.SingleCallReceipt

        assertEquals("CALL_COMPLETED", receipt.receipt.status)
    }

    @Test
    fun recoveryCancellationHidesTheOldUserTurnAndItsLateAssistant() {
        val oldUser = event(1L, StableConversationLedgerEventType.USER_TURN_ACCEPTED).copy(
            eventId = "old-user",
            commandId = "old-command",
            payload = JsonParser().parse("""{"modelTurnId":"old-turn","text":"断网前输入"}""").asJsonObject,
        )
        val cancellation = event(2L, StableConversationLedgerEventType.RUN_CANCELLED).copy(
            eventId = "old-cancelled",
            commandId = "old-command",
            payload = JsonParser().parse(
                """{"reason":"superseded_by_recovery_revision","stage":"recovery_revision"}"""
            ).asJsonObject,
        )
        val lateAssistant = event(3L, StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED).copy(
            eventId = "late-assistant",
            commandId = "old-command",
            payload = JsonParser().parse("""{"modelTurnId":"old-turn","text":"迟到回复"}""").asJsonObject,
        )
        val mergedUser = event(4L, StableConversationLedgerEventType.USER_TURN_ACCEPTED).copy(
            eventId = "merged-user",
            commandId = "new-command",
            payload = JsonParser().parse("""{"modelTurnId":"new-turn","text":"断网前输入 恢复后输入"}""").asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(
            listOf(oldUser, cancellation, lateAssistant, mergedUser)
        )

        assertEquals(1, state.items.size)
        assertEquals(
            "断网前输入 恢复后输入",
            (state.items.single().payload as ConversationTimelinePayload.UserMessage).text,
        )
    }

    @Test
    fun assistantCommittedBeforeRecoveryCancellationRemainsVisible() {
        val oldUser = event(1L, StableConversationLedgerEventType.USER_TURN_ACCEPTED).copy(
            eventId = "old-user",
            commandId = "old-command",
            payload = JsonParser().parse("""{"modelTurnId":"old-turn","text":"原输入"}""").asJsonObject,
        )
        val originalAssistant = event(2L, StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED).copy(
            eventId = "original-assistant",
            commandId = "old-command",
            payload = JsonParser().parse("""{"modelTurnId":"old-turn","text":"原回复"}""").asJsonObject,
        )
        val cancellation = event(3L, StableConversationLedgerEventType.RUN_CANCELLED).copy(
            eventId = "old-cancelled",
            commandId = "old-command",
            payload = JsonParser().parse(
                """{"reason":"superseded_by_recovery_revision","stage":"recovery_revision"}"""
            ).asJsonObject,
        )

        val state = ConversationLedgerTimelineReducer.reduceAll(
            listOf(oldUser, originalAssistant, cancellation)
        )

        assertEquals(
            listOf("原输入", "原回复"),
            state.items.map {
                when (val payload = it.payload) {
                    is ConversationTimelinePayload.UserMessage -> payload.text
                    is ConversationTimelinePayload.AssistantMessage -> payload.text
                    else -> error("unexpected payload")
                }
            },
        )
    }

    private fun event(sequence: Long, type: StableConversationLedgerEventType) = ConversationLedgerEvent(
        eventId = "event-1", sessionId = "session-1", sequence = sequence,
        type = ConversationLedgerEventType.Known(type), schemaVersion = 1, idempotencyKey = "key-1",
        occurredAt = "2026-07-21T00:00:00Z", committedAt = "2026-07-21T00:00:01Z",
        payload = JsonParser().parse("{\"text\":\"hello\"}").asJsonObject,
    )
}
