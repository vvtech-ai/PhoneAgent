package com.vvtech.aiassistant.callengine

import com.vvtech.aiassistant.domain.call.CallFailureClassifier
import com.vvtech.aiassistant.domain.call.CallFailureKind

internal data class AssistantSipAccount(
    val id: String,
    val server: String,
    val port: Int,
    val username: String,
    val password: String,
    val callerNumber: String
) {
    val configured: Boolean
        get() = server.isNotBlank() && username.isNotBlank() && password.isNotBlank()
}

internal enum class AssistantCallMode {
    NORMAL,
    TRANSLATION
}

internal enum class AssistantCallPhase {
    IDLE,
    REGISTERING,
    DIALING,
    RINGING,
    CONNECTED,
    TRANSLATING,
    ENDED,
    FAILED
}

internal data class AssistantCallRequest(
    val phoneNumber: String,
    val displayName: String = "",
    val countryDialCode: String,
    val countryIso: String = "",
    val mode: AssistantCallMode,
    val provider: String = "qwen",
    val myLanguage: String = "zh",
    val peerLanguage: String = "en",
    val playOriginalAudio: Boolean = false,
    val originalAudioGainPercent: Int = 50,
    val originalAudioVolumePercent: Int = 100,
    val selectedDomesticSipAccountId: String = "auto",
    val selectedInternationalSipAccountId: String = "auto"
)

internal data class AssistantCallSnapshot(
    val sessionId: String = "",
    val phoneNumber: String = "",
    val mode: AssistantCallMode = AssistantCallMode.NORMAL,
    val phase: AssistantCallPhase = AssistantCallPhase.IDLE,
    val muted: Boolean = false,
    val speakerEnabled: Boolean = true,
    val connectedAtMillis: Long? = null,
    val endedAtMillis: Long? = null,
    val failureReason: String = "",
    val terminalTransition: Boolean = false
) {
    val active: Boolean
        get() = phase !in setOf(
            AssistantCallPhase.IDLE,
            AssistantCallPhase.ENDED,
            AssistantCallPhase.FAILED
        )
}

internal sealed interface AssistantCallEngineEvent {
    data class PhaseChanged(val phase: AssistantCallPhase) : AssistantCallEngineEvent
    object ModelReady : AssistantCallEngineEvent
    data class Transcript(
        val id: String,
        val role: String,
        val sourceLanguage: String,
        val sourceText: String,
        val translatedLanguage: String,
        val translatedText: String,
        val final: Boolean
    ) : AssistantCallEngineEvent
    data class Failure(
        val message: String,
        val sipMethod: String? = null,
        val sipStatusCode: Int? = null,
        val failureKind: CallFailureKind = CallFailureClassifier.fromSip(
            sipMethod = sipMethod,
            statusCode = sipStatusCode
        )
    ) : AssistantCallEngineEvent
    object Ended : AssistantCallEngineEvent
}

internal interface AssistantCallEngineGateway {
    fun start(request: AssistantCallRequest, onEvent: (AssistantCallEngineEvent) -> Unit)
    fun setMuted(muted: Boolean)
    fun setSpeakerEnabled(enabled: Boolean)
    fun sendDtmf(digit: Char)
    fun hangup()
    fun release()
}
