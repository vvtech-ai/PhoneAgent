package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelDeadVoiceInitialApiTest {
    @Test
    fun viewModelDoesNotKeepDeadVoiceInitialStateOrBeginApis() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()

        assertFalse(viewModel.contains("voiceInitialNeedPrivateRoom"))
        assertFalse(viewModel.contains("voiceInitialAskMinimumSpend"))
        assertFalse(viewModel.contains("voiceInitialAllowHall"))
        assertFalse(viewModel.contains("voiceInitialHotelDetailSummary"))
        assertFalse(viewModel.contains("clearVoiceInitialDetailPreferences"))
        assertFalse(viewModel.contains("beginVoiceDefaultContactConfirmation"))
        assertFalse(viewModel.contains("beginVoiceContactReentry"))
        assertFalse(viewModel.contains("beginVoiceDetailSupplementPrompt"))
        assertFalse(viewModel.contains("beginVoiceSummaryConfirmationPrompt"))
    }

    @Test
    fun voiceEntryHandlerDoesNotCallDeadVoiceInitialCleanup() {
        val handler = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/VoiceEntryActionHandler.kt"
        ).readText()

        assertFalse(handler.contains("clearVoiceInitialDetailPreferences"))
    }

    @Test
    fun singleFlowPageHostUsesExplicitNoOpsForDeadVoiceBeginCallbacks() {
        val host = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantSingleFlowPageHost.kt")
            .readText()

        assertTrue(host.contains("onBeginVoiceContactReentry = {},"))
        assertTrue(host.contains("onBeginVoiceDefaultContactConfirmation = {},"))
        assertTrue(host.contains("onBeginVoiceDetailSupplementPrompt = {},"))
        assertTrue(host.contains("onBeginVoiceSummaryConfirmation = {},"))
        assertFalse(host.contains("assistantViewModel.beginVoice"))
    }
}
