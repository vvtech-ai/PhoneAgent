package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamSseEventParserTest {

    private fun parser(): AgentStreamSseEventParser {
        return AgentStreamSseEventParser(
            terminalCallResultLogger = { _, _, _, _, _, _ -> }
        )
    }

    @Test
    fun rawTextDeltaIsParsed() {
        val event = parser().parse("text_delta", """{"text":"hello"}""")

        assertEquals(AgentStreamEvent.TextDelta("hello"), event)
    }

    @Test
    fun heartbeatIsParsedWithoutPayload() {
        val event = parser().parse("heartbeat", "")

        assertTrue(event is AgentStreamEvent.Heartbeat)
    }

    @Test
    fun timelineCommittedEnvelopeParsesNestedDurableEvent() {
        val event = parser().parse(
            "timeline_committed",
            """
            {
              "event": "timeline_committed",
              "data": {
                "eventId": "event-17",
                "sessionId": "session-success",
                "sequence": 17,
                "eventType": "ASSISTANT_TURN_COMMITTED",
                "schemaVersion": 1,
                "idempotencyKey": "key-17",
                "occurredAt": "2026-07-23T06:19:46Z",
                "committedAt": "2026-07-23T06:19:46Z",
                "payload": {
                  "modelTurnId": "turn-17",
                  "text": "打过去了，对方接了，我已经帮您问候过了。",
                  "finishReason": "call_result"
                }
              }
            }
            """.trimIndent()
        )

        val committed = event as AgentStreamEvent.TimelineCommitted
        assertEquals("session-success", committed.event.sessionId)
        assertEquals(17L, committed.event.sequence)
        assertEquals("ASSISTANT_TURN_COMMITTED", committed.event.type.wireName)
        assertEquals(
            "打过去了，对方接了，我已经帮您问候过了。",
            committed.event.payload.get("text").asString
        )
    }

    @Test
    fun permissionRequestClientEventIsParsed() {
        val event = parser().parse(
            "request_permission",
            """
            {
              "sessionId": "s1",
              "displayMessage": "需要联系人权限",
              "data": {
                "pendingToolCallId": "p1",
                "permissionRequest": {
                  "permissionKey": "contacts",
                  "androidPermission": "android.permission.READ_CONTACTS",
                  "reason": "用于查找联系人",
                  "statusBeforeRequest": "DENIED"
                }
              }
            }
            """.trimIndent()
        )

        val signal = event as AgentStreamEvent.Signal
        assertEquals("REQUEST_PERMISSION", signal.payload.type)
        assertEquals("p1", signal.payload.pendingToolCallId)
        assertEquals("contacts", signal.payload.permissionRequest?.permissionKey)
        assertEquals("android.permission.READ_CONTACTS", signal.payload.permissionRequest?.androidPermission)
    }

    @Test
    fun toolCardClientEventUsesConditionsAsBodyFallback() {
        val event = parser().parse(
            "tool_card",
            """
            {
              "displayMessage": "已完成查询",
              "data": {
                "toolCallId": "tool-1",
                "toolName": "restaurant.search",
                "methodLabel": "",
                "conditions": [
                  {"label": "city", "value": "北海"},
                  {"label": "privateRoom", "value": true}
                ],
                "status": "COMPLETED"
              }
            }
            """.trimIndent()
        )

        val toolCard = event as AgentStreamEvent.ToolCard
        assertEquals("tool-1", toolCard.card.id)
        assertEquals("restaurant.search", toolCard.card.toolName)
        assertEquals("restaurant.search", toolCard.card.methodLabel)
        assertEquals("city: \"北海\"\nprivateRoom: true", toolCard.card.body)
        assertEquals("已完成查询", toolCard.card.result)
    }

    @Test
    fun terminalTaskCompletedCallResultIsParsed() {
        val event = parser().parse(
            "task_completed",
            """
            {
              "sessionId": "s2",
              "displayMessage": "通话完成",
              "data": {
                "callResult": {
                  "status": "SUCCESS",
                  "headline": "已接通",
                  "detail": "已确认包间",
                  "metadata": {
                    "agentOutcome": "SUCCESS",
                    "callId": "c1",
                    "taskId": "t1"
                  }
                }
              }
            }
            """.trimIndent()
        )

        val final = event as AgentStreamEvent.Final
        assertEquals("CALL_RESULT", final.payload.type)
        assertEquals("SUCCESS", final.payload.callResult?.status)
        assertEquals("通话完成", final.payload.text)
    }

    @Test
    fun structuredTaskFailurePreservesClassificationAndTrace() {
        val event = parser().parse(
            "task_failed",
            """
            {
              "sessionId": "s3",
              "displayMessage": "当前任务内容较长，已尝试压缩上下文",
              "data": {
                "errorCode": "MODEL_CONTEXT_LIMIT",
                "category": "MODEL",
                "retryable": false,
                "recoveryAction": "COMPACT_CONTEXT",
                "traceId": "trace-3",
                "stage": "model"
              }
            }
            """.trimIndent()
        ) as AgentStreamEvent.Err

        assertEquals("MODEL_CONTEXT_LIMIT", event.errorCode)
        assertEquals("MODEL", event.category)
        assertEquals(false, event.retryable)
        assertEquals("COMPACT_CONTEXT", event.recoveryAction)
        assertEquals("trace-3", event.traceId)
        assertEquals("model", event.stage)
        assertTrue(event.hasStructuredFailure)
        assertEquals(false, event.isNetworkFailure)
    }

    @Test
    fun unknownAndMalformedEventsAreDropped() {
        assertNull(parser().parse("unknown_event", """{"text":"ignored"}"""))
        assertNull(parser().parse("text_delta", "{bad json"))
    }
}
