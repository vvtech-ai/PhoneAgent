package com.vvtech.aiassistant.data.repository.timeline

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TimelineSyncLoggerTest {
    @Test
    fun productionLoggerEmitsOnlyWhitelistedFieldsAndHashesSessionId() {
        var capturedTag = ""
        var capturedLine = ""
        val logger = AppFileTimelineSyncLogger { tag, line ->
            capturedTag = tag
            capturedLine = line
        }
        val rawSession = "session-13800138000-secret-token-payload-transcript"

        logger.record(event(rawSession))

        assertEquals("TIMELINE_STATE", capturedTag)
        assertEquals(
            TimelineSyncLogContract.allowedFields - "schemaVersion",
            capturedLine.split(' ').map { it.substringBefore('=') }.toSet(),
        )
        assertTrue(capturedLine.contains("logEvent=TIMELINE_SYNC"))
        assertTrue(capturedLine.contains("sessionId=sha256:"))
        assertFalse(capturedLine.contains(rawSession))
        listOf("13800138000", "secret-token", "payload", "transcript").forEach { sensitive ->
            assertFalse("sensitive value leaked: $sensitive", capturedLine.contains(sensitive))
        }
    }

    @Test
    fun optionalSchemaVersionIsTheOnlyAdditionalField() {
        val fields = TimelineSyncLogContract.fields(event("session-1").copy(schemaVersion = 99))

        assertEquals(TimelineSyncLogContract.allowedFields, fields.keys)
        assertEquals("99", fields["schemaVersion"])
        assertFalse(fields.keys.any { it in ForbiddenRawFields })
    }

    private fun event(sessionId: String) = TimelineSyncLogEvent(
        eventName = TimelineSyncLogEventName.Sync,
        sessionId = sessionId,
        fromSequence = 4L,
        toSequence = 7L,
        eventCount = 3,
        source = TimelineSyncLogSource.Rest,
        result = TimelineSyncLogResult.Success,
        reason = TimelineSyncLogReason.PageSynced,
    )

    private companion object {
        val ForbiddenRawFields = setOf(
            "accountId", "phone", "phoneNumber", "recipient", "transcript", "prompt", "token",
            "authorization", "payload", "payloadJson", "arguments", "resultJson", "messageText",
        )
    }
}
