package com.vvtech.aiassistant.data.local.voiceclone

import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceCloneVerificationEnvironmentProviderTest {
    @Test
    fun `device model is normalized and length limited`() {
        assertEquals("Pixel 10 Pro", sanitizeVoiceCloneDeviceModel("  Pixel   10 Pro  "))
        assertEquals(64, sanitizeVoiceCloneDeviceModel("x".repeat(100)).length)
        assertEquals("unknown", sanitizeVoiceCloneDeviceModel("  "))
    }

    @Test
    fun `network type uses stable transport names`() {
        assertEquals("VPN", selectVoiceCloneNetworkType(true, true, false, false, true))
        assertEquals("WIFI", selectVoiceCloneNetworkType(false, true, false, false, true))
        assertEquals("CELLULAR", selectVoiceCloneNetworkType(false, false, true, false, true))
        assertEquals("ETHERNET", selectVoiceCloneNetworkType(false, false, false, true, true))
        assertEquals("OTHER", selectVoiceCloneNetworkType(false, false, false, false, true))
        assertEquals("NONE", selectVoiceCloneNetworkType(false, false, false, false, false))
    }
}
