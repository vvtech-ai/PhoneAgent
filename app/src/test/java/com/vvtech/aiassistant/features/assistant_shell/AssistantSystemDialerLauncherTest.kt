package com.vvtech.aiassistant.features.assistant_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantSystemDialerLauncherTest {
    @Test
    fun systemDialIntentUsesActionDialAndNormalizedTelTarget() {
        val intent = buildAssistantSystemDialIntentSpec("+81 90-1234-5678")

        requireNotNull(intent)
        assertEquals("android.intent.action.DIAL", intent.action)
        assertEquals("tel:+819012345678", intent.uri)
    }

    @Test
    fun systemDialIntentRejectsBlankOrNonNumericTarget() {
        assertEquals(null, buildAssistantSystemDialIntentSpec(""))
        assertEquals(null, buildAssistantSystemDialIntentSpec("abc"))
    }

    @Test
    fun systemDialIntentKeepsChinaLandlineWithoutAddingCountryCode() {
        val intent = buildAssistantSystemDialIntentSpec("010-8888-6666")

        requireNotNull(intent)
        assertEquals("tel:01088886666", intent.uri)
    }
}
