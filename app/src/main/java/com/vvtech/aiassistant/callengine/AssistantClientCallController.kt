package com.vvtech.aiassistant.callengine

import com.vvtech.aiassistant.domain.call.CallFailureClassifier
import com.vvtech.aiassistant.domain.call.CallFailureKind
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

internal data class AssistantClientCallTranscript(
    val id: String,
    val role: String,
    val sourceLanguage: String,
    val sourceText: String,
    val translatedLanguage: String,
    val translatedText: String,
    val final: Boolean
)

internal data class AssistantClientCallState(
    val sessionId: String = "",
    val request: AssistantCallRequest? = null,
    val phase: AssistantCallPhase = AssistantCallPhase.IDLE,
    val startedAtMillis: Long = 0,
    val connectedAtMillis: Long? = null,
    val elapsedSeconds: Int = 0,
    val muted: Boolean = false,
    val speakerEnabled: Boolean = true,
    val transcripts: List<AssistantClientCallTranscript> = emptyList(),
    val failureReason: String = "",
    val failureKind: CallFailureKind = CallFailureKind.UNKNOWN
) {
    val visible: Boolean
        get() = phase != AssistantCallPhase.IDLE
}

internal data class AssistantClientCallResult(
    val sessionId: String,
    val request: AssistantCallRequest,
    val startedAtMillis: Long,
    val connectedAtMillis: Long?,
    val endedAtMillis: Long,
    val success: Boolean,
    val failureReason: String,
    val failureKind: CallFailureKind,
    val transcripts: List<AssistantClientCallTranscript>
) {
    val durationSeconds: Long
        get() = connectedAtMillis?.let { ((endedAtMillis - it) / 1_000).coerceAtLeast(0) } ?: 0
}

internal class AssistantClientCallController(
    private val gateway: AssistantCallEngineGateway,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onTerminal: (AssistantClientCallResult) -> Unit
) {
    private val mutableState = MutableStateFlow(AssistantClientCallState())
    private val terminalHandled = AtomicBoolean(false)
    val state: StateFlow<AssistantClientCallState> = mutableState.asStateFlow()

    fun start(request: AssistantCallRequest): Boolean {
        if (mutableState.value.visible || request.phoneNumber.isBlank()) return false
        terminalHandled.set(false)
        val sessionId = UUID.randomUUID().toString()
        mutableState.value = AssistantClientCallState(
            sessionId = sessionId,
            request = request,
            phase = AssistantCallPhase.REGISTERING,
            startedAtMillis = clock()
        )
        runCatching { gateway.start(request, ::onEngineEvent) }
            .onFailure {
                finish(
                    success = false,
                    failureReason = it.message ?: "客户端 SIP 启动失败",
                    failureKind = CallFailureClassifier.fromThrowable(it)
                )
            }
        return true
    }

    fun toggleMuted() {
        val current = mutableState.value
        if (!current.visible) return
        val next = !current.muted
        gateway.setMuted(next)
        mutableState.value = current.copy(muted = next)
    }

    fun toggleSpeaker() {
        val current = mutableState.value
        if (!current.visible) return
        val next = !current.speakerEnabled
        gateway.setSpeakerEnabled(next)
        mutableState.value = current.copy(speakerEnabled = next)
    }

    fun sendDtmf(digit: Char) {
        if (mutableState.value.visible) gateway.sendDtmf(digit)
    }

    fun hangup() {
        if (!mutableState.value.visible) return
        gateway.hangup()
    }

    fun tick() {
        val current = mutableState.value
        val connectedAt = current.connectedAtMillis ?: return
        if (!current.visible) return
        mutableState.value = current.copy(
            elapsedSeconds = ((clock() - connectedAt) / 1_000).coerceAtLeast(0).toInt()
        )
    }

    fun release() {
        gateway.release()
        mutableState.value = AssistantClientCallState()
    }

    private fun onEngineEvent(event: AssistantCallEngineEvent) {
        when (event) {
            is AssistantCallEngineEvent.PhaseChanged -> updatePhase(event.phase)
            is AssistantCallEngineEvent.Transcript -> appendTranscript(event)
            AssistantCallEngineEvent.ModelReady -> Unit
            is AssistantCallEngineEvent.Failure -> finish(
                success = false,
                failureReason = event.message,
                failureKind = event.failureKind
            )
            AssistantCallEngineEvent.Ended -> finish(
                success = mutableState.value.connectedAtMillis != null,
                failureReason = ""
            )
        }
    }

    private fun updatePhase(phase: AssistantCallPhase) {
        val current = mutableState.value
        if (!current.visible) return
        val connectedAt = if (
            phase == AssistantCallPhase.CONNECTED ||
            phase == AssistantCallPhase.TRANSLATING
        ) {
            current.connectedAtMillis ?: clock()
        } else {
            current.connectedAtMillis
        }
        mutableState.value = current.copy(phase = phase, connectedAtMillis = connectedAt)
    }

    private fun appendTranscript(event: AssistantCallEngineEvent.Transcript) {
        val current = mutableState.value
        if (!current.visible) return
        val stableId = event.id.ifBlank { "${event.role}:${current.transcripts.size}" }
        val line = AssistantClientCallTranscript(
            id = stableId,
            role = event.role,
            sourceLanguage = event.sourceLanguage,
            sourceText = event.sourceText,
            translatedLanguage = event.translatedLanguage,
            translatedText = event.translatedText,
            final = event.final
        )
        val existingIndex = current.transcripts.indexOfFirst { it.id == stableId }
        val updated = if (existingIndex >= 0) {
            current.transcripts.toMutableList().apply { set(existingIndex, line) }
        } else {
            current.transcripts + line
        }
        mutableState.value = current.copy(transcripts = updated)
    }

    private fun finish(
        success: Boolean,
        failureReason: String,
        failureKind: CallFailureKind = CallFailureKind.UNKNOWN
    ) {
        if (!terminalHandled.compareAndSet(false, true)) return
        val current = mutableState.value
        val request = current.request ?: return
        mutableState.value = current.copy(
            phase = if (success) AssistantCallPhase.ENDED else AssistantCallPhase.FAILED,
            failureReason = failureReason,
            failureKind = failureKind
        )
        onTerminal(
            AssistantClientCallResult(
                sessionId = current.sessionId,
                request = request,
                startedAtMillis = current.startedAtMillis,
                connectedAtMillis = current.connectedAtMillis,
                endedAtMillis = clock(),
                success = success,
                failureReason = failureReason,
                failureKind = failureKind,
                transcripts = current.transcripts
            )
        )
        mutableState.value = AssistantClientCallState()
    }
}
