package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.domain.call.CallFailureClassifier
import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironment
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import com.vvtech.aiassistant.domain.translation.TranslationCallPlan

enum class TranslationCallPhase {
    Idle,
    Preflight,
    Dialing,
    Ringing,
    Connected,
    Translating,
    Ended,
    Failed
}

data class TranslationCallTranscriptItem(
    val segmentId: String,
    val sourceLeg: String,
    val sourceLanguage: String,
    val sourceText: String,
    val translatedLanguage: String,
    val translatedText: String,
    val final: Boolean
)

data class TranslationCallUiState(
    val callId: String = "",
    val plan: TranslationCallPlan? = null,
    val targetDisplayName: String = "",
    val dialCountryIso: String = "",
    val myLanguage: String = "",
    val peerLanguage: String = "",
    val phase: TranslationCallPhase = TranslationCallPhase.Idle,
    val environment: TranslationCallEnvironment? = null,
    val startedAtMs: Long = 0L,
    val connectedAtMs: Long? = null,
    val elapsedSeconds: Int = 0,
    val muted: Boolean = false,
    val speakerEnabled: Boolean = true,
    val transcripts: List<TranslationCallTranscriptItem> = emptyList(),
    val failureReason: String = "",
    val failureKind: CallFailureKind = CallFailureKind.UNKNOWN
) {
    val visible: Boolean
        get() = phase != TranslationCallPhase.Idle

    val terminal: Boolean
        get() = phase == TranslationCallPhase.Ended ||
            phase == TranslationCallPhase.Failed
}

sealed interface TranslationCallUiAction {
    object ToggleMuted : TranslationCallUiAction
    object ToggleSpeaker : TranslationCallUiAction
    data class SendDtmf(val digit: Char) : TranslationCallUiAction
    object Hangup : TranslationCallUiAction
    object DismissTerminal : TranslationCallUiAction
}

sealed interface TranslationCallUiEffect {
    data class ShowMessage(val message: String) : TranslationCallUiEffect
    data class ShowFailure(val failureKind: CallFailureKind) : TranslationCallUiEffect
    data class Finished(val callId: String, val success: Boolean) : TranslationCallUiEffect
}

data class TranslationCallSessionRequest(
    val callId: String,
    val plan: TranslationCallPlan,
    val myLanguage: String,
    val peerLanguage: String,
    val playOriginalAudio: Boolean = false,
    val originalAudioGainPercent: Int = 50,
    val originalAudioVolumePercent: Int = 100
)

sealed interface TranslationCallSessionEvent {
    val callId: String

    data class PhaseChanged(
        override val callId: String,
        val phase: TranslationCallPhase
    ) : TranslationCallSessionEvent

    data class EnvironmentChanged(
        override val callId: String,
        val patch: TranslationCallEnvironmentPatch
    ) : TranslationCallSessionEvent

    data class Transcript(
        override val callId: String,
        val item: TranslationCallTranscriptItem
    ) : TranslationCallSessionEvent

    data class Failure(
        override val callId: String,
        val message: String,
        val sipMethod: String? = null,
        val sipStatusCode: Int? = null,
        val failureKind: CallFailureKind = CallFailureClassifier.fromSip(
            sipMethod = sipMethod,
            statusCode = sipStatusCode
        )
    ) : TranslationCallSessionEvent

    data class Ended(override val callId: String) : TranslationCallSessionEvent
}

interface TranslationCallSessionGateway {
    fun start(
        request: TranslationCallSessionRequest,
        onEvent: (TranslationCallSessionEvent) -> Unit
    )

    fun setMuted(muted: Boolean)
    fun setSpeakerEnabled(enabled: Boolean)
    fun sendDtmf(digit: Char)
    fun hangup()
    fun release()
}
