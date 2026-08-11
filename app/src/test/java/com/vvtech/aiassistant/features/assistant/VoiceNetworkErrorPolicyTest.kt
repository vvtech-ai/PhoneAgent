package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceNetworkErrorPolicyTest {

    @Test
    fun recognizesNetworkTaskFailuresAsUserFacingNetworkErrors() {
        assertTrue(containsSensitiveNetworkError("HTTP 503 Service Unavailable"))
        assertTrue(containsSensitiveNetworkError("voice tts failed: first_audio_timeout"))
        assertTrue(containsSensitiveNetworkError("voice tts failed: completion_timeout"))
        assertTrue(containsSensitiveNetworkError("网络异常，请稍后重试"))
        assertTrue(containsSensitiveNetworkError("服务响应超时，请重试"))
        assertEquals(
            userFacingNetworkErrorMessage(VoiceLanguage.Chinese),
            sanitizeUserFacingError("HTTP 503 Service Unavailable", VoiceLanguage.Chinese)
        )
    }

    @Test
    fun distinguishesTransportFailuresFromProviderAndCapacityFailures() {
        assertTrue(containsTransportNetworkError("Unable to resolve host api.example.com"))
        assertTrue(containsTransportNetworkError("connection reset by peer"))
        assertTrue(containsTransportNetworkError("network timeout"))
        assertTrue(containsTransportNetworkError("网络连接异常，请稍后重试"))
        assertFalse(containsTransportNetworkError("HTTP 503 Service Unavailable"))
        assertFalse(containsTransportNetworkError("HTTP 429 Too Many Requests"))
        assertFalse(containsTransportNetworkError("服务暂时不可用，请稍后再试"))
        assertFalse(containsTransportNetworkError("model context length exceeded"))
    }

    @Test
    fun voiceNetworkFailuresRouteToTaskNetworkErrorState() {
        val agentStream = File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
            .readText()
        val voiceRuntime = File("src/main/java/com/vvtech/aiassistant/features/assistant/VoiceRuntimeHandler.kt")
            .readText()
        val voiceLifecycle = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceRuntimeLifecycleController.kt")
            .readText()
        val voiceCompletion = File("src/main/java/com/vvtech/aiassistant/features/assistant_voice/VoiceDuplexCompletionController.kt")
            .readText()

        assertTrue(
            "Agent stream voice failures must set taskStatus=NETWORK_ERROR instead of voice recovery status.",
            agentStream.contains("applyNetworkTaskErrorState")
        )
        assertTrue(
            "Backend ASR fallback failures must set taskStatus=NETWORK_ERROR instead of paused status.",
            voiceRuntime.contains("pauseVoiceAfterBackendSpeechFallbackFailure") &&
                voiceLifecycle.contains("applyNetworkTaskErrorState")
        )
        assertTrue(
            "Realtime TTS/ASR timeout pauses must show network error status instead of generic paused status.",
            voiceCompletion.contains("containsTransportNetworkError(reason)") &&
                voiceCompletion.contains("networkTaskErrorStatusMessage(currentVoiceLanguage())")
        )
    }
}
