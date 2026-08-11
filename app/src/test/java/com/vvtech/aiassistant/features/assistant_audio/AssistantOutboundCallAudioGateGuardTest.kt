package com.vvtech.aiassistant.features.assistant_audio

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantOutboundCallAudioGateGuardTest {
    @Test
    fun viewModelDelegatesOutboundCallAudioGateWork() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()
        val facade = File("src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelVoiceCallFacades.kt")
            .readText()
        val gate = File("src/main/java/com/vvtech/aiassistant/features/assistant_audio/AssistantOutboundCallAudioGate.kt")
            .readText()

        assertFalse(viewModel.contains("outboundCallAudioGate.isSuppressed()"))
        assertTrue(facade.contains("outboundCallAudioGate.isSuppressed()"))
        assertTrue(facade.contains("outboundCallAudioGate.snapshot()"))
        assertTrue(facade.contains("outboundCallAudioGate.log(reason, suppressed)"))
        assertTrue(facade.contains("outboundCallAudioGate.beginSuppression(reason)"))
        assertTrue(facade.contains("outboundCallAudioGate.endSuppression(reason)"))

        assertFalse(viewModel.contains("CALL_AUDIO_GATE"))
        assertFalse(viewModel.contains("begin_suppression:"))
        assertTrue(gate.contains("CALL_AUDIO_GATE"))
        assertTrue(gate.contains("begin_suppression:"))
        assertTrue(gate.contains("suspendDialogAudioForCall(reason)"))
    }
}
