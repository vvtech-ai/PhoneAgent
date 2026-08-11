package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.DialCallKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSystemPhoneCallRecordPolicyTest {
    @Test
    fun successfulSystemCallCreatesOneNormalZeroDurationRecord() {
        val record = buildSystemPhoneCallRecord(
            plan = AssistantSystemPhoneCallUiPlan(
                normalizedNumber = "+819012345678",
                source = AssistantSystemPhoneCallSourceDial,
                returnPageName = "Calls"
            ),
            occurredAtMillis = 1_000L
        )

        assertEquals(DialCallKind.NORMAL, record.callKind)
        assertEquals("+819012345678", record.phoneNumber)
        assertEquals("00:00", record.durationText)
        assertTrue(record.success)
    }
}
