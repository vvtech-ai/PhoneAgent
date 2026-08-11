package com.vvtech.aiassistant.features.assistant_initialization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantInitializationPolicyTest {

    @Test
    fun `initialization is shown only after identity loaded with blank name`() {
        assertTrue(
            shouldShowAssistantInitialization(
                loadState = AssistantInitializationLoadState.LOADED,
                identityName = " "
            )
        )
        assertFalse(
            shouldShowAssistantInitialization(
                loadState = AssistantInitializationLoadState.UNKNOWN,
                identityName = null
            )
        )
        assertFalse(
            shouldShowAssistantInitialization(
                loadState = AssistantInitializationLoadState.LOADING,
                identityName = null
            )
        )
        assertFalse(
            shouldShowAssistantInitialization(
                loadState = AssistantInitializationLoadState.FAILED,
                identityName = null
            )
        )
    }

    @Test
    fun `recovery targets include only unknown or failed dependencies`() {
        val targets = assistantInitializationRecoveryTargets(
            AssistantInitializationSnapshot(
                identity = AssistantInitializationLoadState.FAILED,
                callProvider = AssistantInitializationLoadState.LOADED,
                translationProvider = AssistantInitializationLoadState.UNKNOWN
            )
        )

        assertEquals(
            setOf(
                AssistantInitializationResource.IDENTITY,
                AssistantInitializationResource.TRANSLATION_PROVIDER
            ),
            targets
        )
    }

    @Test
    fun `recovery is empty while dependencies are loaded or loading`() {
        val targets = assistantInitializationRecoveryTargets(
            AssistantInitializationSnapshot(
                identity = AssistantInitializationLoadState.LOADED,
                callProvider = AssistantInitializationLoadState.LOADING,
                translationProvider = AssistantInitializationLoadState.LOADED
            )
        )

        assertTrue(targets.isEmpty())
    }

    @Test
    fun `provider failed refresh remains recoverable even with cached response`() {
        assertEquals(
            AssistantInitializationLoadState.FAILED,
            assistantProviderLoadState(
                loading = false,
                hasResponse = true,
                error = "network unavailable"
            )
        )
        assertEquals(
            AssistantInitializationLoadState.LOADED,
            assistantProviderLoadState(
                loading = false,
                hasResponse = true,
                error = null
            )
        )
    }
}
