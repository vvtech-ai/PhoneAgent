package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.V88NetworkMode
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantOnlineEntryNetworkGuardTest {
    @Test
    fun normalModeBlocksEntryWhenDefaultNetworkHasNoValidatedInternet() {
        assertTrue(
            shouldBlockAssistantOnlineEntry(
                networkMode = V88NetworkMode.Normal,
                hasValidatedInternet = false
            )
        )
    }

    @Test
    fun simulatedOfflineBlocksEntryEvenWhenInternetIsValidated() {
        assertTrue(
            shouldBlockAssistantOnlineEntry(
                networkMode = V88NetworkMode.Offline,
                hasValidatedInternet = true
            )
        )
    }

    @Test
    fun normalModeAllowsEntryWhenInternetIsValidated() {
        assertFalse(
            shouldBlockAssistantOnlineEntry(
                networkMode = V88NetworkMode.Normal,
                hasValidatedInternet = true
            )
        )
    }
}
