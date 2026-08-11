package com.vvtech.aiassistant.logging

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RuntimeStateLoggerTest {
    @Test
    fun formatsStableRuntimeStateFieldsInOrder() {
        val logLine = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.TASK,
            eventType = "task_refresh_completed",
            traceId = "trace-1",
            commandId = "command-1",
            sessionId = "session-1",
            taskId = "task-1",
            callAttemptId = "attempt-1",
            callId = "call-1",
            eventId = "event-1",
            sequence = 7L,
            provider = "local",
            trigger = "screen_enter",
            stateBefore = "loading",
            stateAfter = "loaded",
            result = "success",
            reason = "screen_enter",
            elapsedMs = 25L,
            message = "refresh completed",
            attributes = mapOf(
                "zeta" to "z",
                "alpha" to "a"
            )
        ).formatForLog()

        assertEquals(
            "eventType=task_refresh_completed " +
                "traceId=trace-1 " +
                "commandId=command-1 " +
                "sessionId=session-1 " +
                "taskId=task-1 " +
                "callAttemptId=attempt-1 " +
                "callId=call-1 " +
                "eventId=event-1 " +
                "sequence=7 " +
                "provider=local " +
                "trigger=screen_enter " +
                "stateBefore=loading " +
                "stateAfter=loaded " +
                "result=success " +
                "reason=screen_enter " +
                "elapsedMs=25 " +
                "attr.alpha=a " +
                "attr.zeta=z " +
                "message=refresh_completed",
            logLine
        )
    }

    @Test
    fun omitsBlankNullAndLiteralNullValues() {
        val logLine = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.APP,
            eventType = "app_event",
            traceId = "",
            sessionId = null,
            stateBefore = "null",
            reason = " ",
            attributes = mapOf(
                "blank" to "",
                "literal" to "null",
                "visible" to "ok"
            )
        ).formatForLog()

        assertEquals("eventType=app_event attr.visible=ok", logLine)
        assertFalse(logLine.contains("traceId="))
        assertFalse(logLine.contains("sessionId="))
        assertFalse(logLine.contains("stateBefore="))
        assertFalse(logLine.contains("reason="))
    }

    @Test
    fun redactsSensitiveKeysAndMasksPhoneLikeValues() {
        val logLine = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.CALL,
            eventType = "call_gate",
            attributes = mapOf(
                "phoneNumber" to "13812345678",
                "token" to "secret-token-value",
                "contactName" to "Alice",
                "transcriptPreview" to "please order dinner",
                "note" to "call 13812345678 now",
                "recordCount" to "12"
            )
        ).formatForLog()

        assertTrue(logLine.contains("attr.phoneNumber=[redacted]"))
        assertTrue(logLine.contains("attr.token=[redacted]"))
        assertTrue(logLine.contains("attr.contactName=[redacted]"))
        assertTrue(logLine.contains("attr.transcriptPreview=[redacted]"))
        assertTrue(logLine.contains("attr.note=call_[digits:11:****5678]_now"))
        assertTrue(logLine.contains("attr.recordCount=12"))
        assertFalse(logLine.contains("13812345678"))
        assertFalse(logLine.contains("secret-token-value"))
        assertFalse(logLine.contains("Alice"))
        assertFalse(logLine.contains("please_order_dinner"))
    }

    @Test
    fun normalizesAttributeKeysNewlinesAndLongValues() {
        val logLine = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.LOG_EXPORT,
            eventType = "log_exported",
            attributes = mapOf(
                "bad key" to "line1\nline2",
                "detail" to "x".repeat(200)
            )
        ).formatForLog()

        assertTrue(logLine.contains("attr.bad_key=line1\\nline2"))
        assertTrue(logLine.contains("attr.detail=${"x".repeat(160)}...[truncated:200]"))
    }
}
