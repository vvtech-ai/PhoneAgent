package com.vvtech.aiassistant.features.assistant_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantOverlayModelActionsTest {
    @Test
    fun disabledModelShowsComingSoonWithoutClosingOrSwitching() {
        val events = mutableListOf<String>()

        handleOverlayVoiceModelSelection(
            modelId = "GPT",
            state = state(selectedVoiceModelId = "QWEN_OMNI_PLUS"),
            callbacks = callbacks(events)
        )

        assertEquals(1, events.size)
        assertTrue(events.first().startsWith("message:"))
        assertTrue(events.first().endsWith("调试中，即将推出。"))
    }

    @Test
    fun unknownProviderShowsComingSoon() {
        val events = mutableListOf<String>()

        handleOverlayVoiceModelSelection(
            modelId = "unknown",
            state = state(selectedVoiceModelId = "QWEN_OMNI_PLUS"),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("message:该模型调试中，即将推出。"), events)
    }

    @Test
    fun switchingProviderShowsBusyMessage() {
        val events = mutableListOf<String>()

        handleOverlayVoiceModelSelection(
            modelId = "DOUBAO",
            state = state(selectedVoiceModelId = "QWEN_OMNI_PLUS", switching = true),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("message:通话模型正在切换中"), events)
    }

    @Test
    fun selectingCurrentModelOnlyClosesSheet() {
        val events = mutableListOf<String>()

        handleOverlayVoiceModelSelection(
            modelId = "QWEN_OMNI_PLUS",
            state = state(selectedVoiceModelId = "QWEN_OMNI_PLUS"),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("sheet:false"), events)
    }

    @Test
    fun selectingAvailableDifferentModelClosesSheetAndSwitchesProvider() {
        val events = mutableListOf<String>()

        handleOverlayVoiceModelSelection(
            modelId = "DOUBAO",
            state = state(selectedVoiceModelId = "QWEN_OMNI_PLUS"),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("sheet:false", "switch:DOUBAO"), events)
    }

    @Test
    fun unavailableProviderDoesNotCloseSheetOrSwitch() {
        val events = mutableListOf<String>()

        handleOverlayVoiceModelSelection(
            modelId = "DOUBAO",
            state = state(
                selectedVoiceModelId = "QWEN_OMNI_PLUS",
                availableProviderIds = setOf("QWEN_OMNI_PLUS")
            ),
            callbacks = callbacks(events)
        )

        assertEquals(1, events.size)
        assertTrue(events.first().startsWith("message:"))
    }

    private fun state(
        selectedVoiceModelId: String,
        availableProviderIds: Set<String> = setOf("QWEN_OMNI_PLUS", "DOUBAO"),
        switching: Boolean = false
    ) = AssistantOverlayModelSelectionState(
        selectedVoiceModelId = selectedVoiceModelId,
        availableVoiceModelIds = availableProviderIds,
        realtimeProviderSwitching = switching
    )

    private fun callbacks(events: MutableList<String>) = AssistantOverlayModelSelectionCallbacks(
        onShowMessage = { events += "message:$it" },
        onShowVoiceModelSheetChange = { events += "sheet:$it" },
        onSwitchRealtimeCallProvider = { events += "switch:$it" }
    )
}
