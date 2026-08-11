package com.vvtech.aiassistant.features.assistant_settings

import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantIdentityProfileStatusTest {

    @Test
    fun usesServerIdentityStatusForSettingsLabel() {
        assertEquals("未填写", AssistantIdentityProfileStatus.fromServer("EMPTY").label)
        assertEquals("已填写", AssistantIdentityProfileStatus.fromServer("FILLED").label)
        assertEquals("已认证", AssistantIdentityProfileStatus.fromServer("VERIFIED").label)
    }

    @Test
    fun unknownServerStatusDoesNotClaimVerification() {
        assertEquals(AssistantIdentityProfileStatus.Empty, AssistantIdentityProfileStatus.fromServer("UNKNOWN"))
        assertEquals(AssistantIdentityProfileStatus.Empty, AssistantIdentityProfileStatus.fromServer(null))
    }
}
