package com.vvtech.aiassistant.callengine

import com.vvtech.aiassistant.domain.call.CallFailureKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantClientCallControllerTest {
    @Test
    fun duplicateTerminalSignalsWriteOnlyOneResult() {
        var now = 1_000L
        val gateway = FakeCallEngineGateway()
        val results = mutableListOf<AssistantClientCallResult>()
        val controller = AssistantClientCallController(
            gateway = gateway,
            clock = { now },
            onTerminal = results::add
        )
        val request = AssistantCallRequest(
            phoneNumber = "13812345678",
            countryDialCode = "86",
            mode = AssistantCallMode.NORMAL
        )

        assertTrue(controller.start(request))
        gateway.emit(AssistantCallEngineEvent.PhaseChanged(AssistantCallPhase.CONNECTED))
        now = 6_000L
        gateway.emit(AssistantCallEngineEvent.Ended)
        gateway.emit(AssistantCallEngineEvent.Failure("duplicate"))

        assertEquals(1, results.size)
        assertEquals(5L, results.single().durationSeconds)
        assertEquals(AssistantCallPhase.IDLE, controller.state.value.phase)
    }

    @Test
    fun transcriptUpdatesOneTurnInPlaceAndKeepsBothSpeakersInOrder() {
        val gateway = FakeCallEngineGateway()
        val controller = AssistantClientCallController(
            gateway = gateway,
            onTerminal = {}
        )
        controller.start(
            AssistantCallRequest(
                phoneNumber = "13812345678",
                countryDialCode = "86",
                mode = AssistantCallMode.TRANSLATION
            )
        )

        gateway.emit(
            AssistantCallEngineEvent.Transcript(
                id = "local-1",
                role = "local",
                sourceLanguage = "zh",
                sourceText = "你好",
                translatedLanguage = "en",
                translatedText = "Hello",
                final = false
            )
        )
        gateway.emit(
            AssistantCallEngineEvent.Transcript(
                id = "local-1",
                role = "local",
                sourceLanguage = "zh",
                sourceText = "你好，请问",
                translatedLanguage = "en",
                translatedText = "Hello, may I ask",
                final = true
            )
        )
        gateway.emit(
            AssistantCallEngineEvent.Transcript(
                id = "remote-1",
                role = "remote",
                sourceLanguage = "en",
                sourceText = "Sure",
                translatedLanguage = "zh",
                translatedText = "可以",
                final = true
            )
        )

        val lines = controller.state.value.transcripts
        assertEquals(2, lines.size)
        assertEquals(listOf("local", "remote"), lines.map { it.role })
        assertEquals("你好，请问", lines.first().sourceText)
        assertEquals("Hello, may I ask", lines.first().translatedText)
        assertTrue(lines.first().final)
    }

    @Test
    fun sipFailureKeepsStructuredKindForPresentation() {
        val gateway = FakeCallEngineGateway()
        val results = mutableListOf<AssistantClientCallResult>()
        val controller = AssistantClientCallController(
            gateway = gateway,
            onTerminal = results::add
        )
        controller.start(
            AssistantCallRequest(
                phoneNumber = "15400000000",
                countryDialCode = "86",
                mode = AssistantCallMode.NORMAL
            )
        )

        gateway.emit(
            AssistantCallEngineEvent.Failure(
                message = "SIP INVITE 失败：503 Service Unavailable",
                sipMethod = "INVITE",
                sipStatusCode = 503
            )
        )

        assertEquals(CallFailureKind.SERVICE_UNAVAILABLE, results.single().failureKind)
        assertEquals(
            "SIP INVITE 失败：503 Service Unavailable",
            results.single().failureReason
        )
    }

    private class FakeCallEngineGateway : AssistantCallEngineGateway {
        private var callback: ((AssistantCallEngineEvent) -> Unit)? = null

        override fun start(
            request: AssistantCallRequest,
            onEvent: (AssistantCallEngineEvent) -> Unit
        ) {
            callback = onEvent
        }

        override fun setMuted(muted: Boolean) = Unit
        override fun setSpeakerEnabled(enabled: Boolean) = Unit
        override fun sendDtmf(digit: Char) = Unit
        override fun hangup() = Unit
        override fun release() = Unit

        fun emit(event: AssistantCallEngineEvent) {
            callback?.invoke(event)
        }
    }
}
