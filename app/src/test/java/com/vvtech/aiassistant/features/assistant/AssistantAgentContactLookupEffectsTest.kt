package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.contacts.DeviceContactPhoneCandidate
import com.vvtech.aiassistant.contacts.DeviceContactsLookupItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantAgentContactLookupEffectsTest {

    @Test
    fun multipleCandidatesAndTypedSourceAreFullyForwardedToAgent() {
        val result = DeviceContactsLookupItem(
            name = "张三",
            status = "MULTIPLE_CANDIDATES",
            matchType = "name_exact",
            candidates = listOf(
                DeviceContactPhoneCandidate("1", "张三", "13800001234"),
                DeviceContactPhoneCandidate("2", "張三", "13900005678")
            )
        ).toAgentDeviceContactResult(AgentContactInputSource.TYPED)

        assertEquals("typed", result["inputSource"])
        assertEquals("MULTIPLE_CANDIDATES", result["status"])
        val candidates = result["candidates"] as List<*>
        assertEquals(2, candidates.size)
        assertTrue(candidates.first() is Map<*, *>)
        assertEquals("13800001234", (candidates.first() as Map<*, *>)["phoneNumber"])
    }
}
