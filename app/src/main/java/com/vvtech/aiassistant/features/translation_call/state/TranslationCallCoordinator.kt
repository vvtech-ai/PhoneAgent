package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.domain.call.CallFailureClassifier
import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentReducer
import com.vvtech.aiassistant.domain.translation.TranslationCallPlan
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

class TranslationCallCoordinator(
    private val gateway: TranslationCallSessionGateway,
    private val clock: () -> Long = System::currentTimeMillis,
    private val idFactory: () -> String = { UUID.randomUUID().toString() }
) {
    private val mutableState = MutableStateFlow(TranslationCallUiState())
    private val mutableEffects = MutableSharedFlow<TranslationCallUiEffect>(
        extraBufferCapacity = 4
    )
    private val terminalHandled = AtomicBoolean(false)

    val state: StateFlow<TranslationCallUiState> = mutableState.asStateFlow()
    val effects: SharedFlow<TranslationCallUiEffect> = mutableEffects.asSharedFlow()

    fun start(
        plan: TranslationCallPlan,
        myLanguage: String,
        peerLanguage: String,
        targetDisplayName: String = "",
        dialCountryIso: String = "",
        playOriginalAudio: Boolean = false,
        originalAudioGainPercent: Int = 50,
        originalAudioVolumePercent: Int = 100
    ): Boolean {
        if (mutableState.value.visible) return false
        val callId = idFactory()
        terminalHandled.set(false)
        mutableState.value = TranslationCallUiState(
            callId = callId,
            plan = plan,
            targetDisplayName = targetDisplayName.trim(),
            dialCountryIso = dialCountryIso.trim(),
            myLanguage = myLanguage,
            peerLanguage = peerLanguage,
            phase = TranslationCallPhase.Preflight,
            environment = TranslationCallEnvironmentReducer.apply(
                null,
                TranslationCallEnvironmentPatch(
                    version = 0,
                    phase = "preflight",
                    sampledAtMs = clock()
                )
            ),
            startedAtMs = clock()
        )
        AppFileLogger.i(
            LogTag,
            "event=start callId=$callId region=${plan.locationCountryIso} " +
                "transport=${plan.transport} provider=${plan.provider} " +
                "targetSuffix=${plan.targetE164.takeLast(4)}"
        )
        runCatching {
            gateway.start(
                TranslationCallSessionRequest(
                    callId = callId,
                    plan = plan,
                    myLanguage = myLanguage,
                    peerLanguage = peerLanguage,
                    playOriginalAudio = playOriginalAudio,
                    originalAudioGainPercent = originalAudioGainPercent,
                    originalAudioVolumePercent = originalAudioVolumePercent
                ),
                ::onSessionEvent
            )
        }.onFailure {
            finish(
                callId = callId,
                success = false,
                reason = it.message ?: "实时翻译通话启动失败",
                failureKind = CallFailureClassifier.fromThrowable(it)
            )
        }
        return true
    }

    fun dispatch(action: TranslationCallUiAction) {
        val current = mutableState.value
        when (action) {
            TranslationCallUiAction.ToggleMuted -> if (!current.terminal) {
                val next = !current.muted
                gateway.setMuted(next)
                mutableState.value = current.copy(muted = next)
            }
            TranslationCallUiAction.ToggleSpeaker -> if (!current.terminal) {
                val next = !current.speakerEnabled
                gateway.setSpeakerEnabled(next)
                mutableState.value = current.copy(speakerEnabled = next)
            }
            is TranslationCallUiAction.SendDtmf -> if (!current.terminal) {
                gateway.sendDtmf(action.digit)
            }
            TranslationCallUiAction.Hangup -> if (!current.terminal) gateway.hangup()
            TranslationCallUiAction.DismissTerminal -> if (current.terminal) {
                mutableState.value = TranslationCallUiState()
            }
        }
    }

    fun tick() {
        val current = mutableState.value
        val connectedAt = current.connectedAtMs ?: return
        if (current.terminal) return
        mutableState.value = current.copy(
            elapsedSeconds = ((clock() - connectedAt) / 1_000L)
                .coerceAtLeast(0L)
                .toInt()
        )
    }

    fun release() {
        gateway.release()
        mutableState.value = TranslationCallUiState()
    }

    private fun onSessionEvent(event: TranslationCallSessionEvent) {
        val current = mutableState.value
        if (event.callId != current.callId || current.terminal) return
        when (event) {
            is TranslationCallSessionEvent.PhaseChanged -> updatePhase(event.phase)
            is TranslationCallSessionEvent.EnvironmentChanged -> {
                mutableState.value = current.copy(
                    environment = TranslationCallEnvironmentReducer.apply(
                        current.environment,
                        event.patch
                    )
                )
            }
            is TranslationCallSessionEvent.Transcript -> appendTranscript(event.item)
            is TranslationCallSessionEvent.Failure ->
                finish(event.callId, false, event.message, event.failureKind)
            is TranslationCallSessionEvent.Ended ->
                finish(event.callId, current.connectedAtMs != null, "")
        }
    }

    private fun updatePhase(phase: TranslationCallPhase) {
        val current = mutableState.value
        val connectedAt = if (
            phase == TranslationCallPhase.Connected ||
            phase == TranslationCallPhase.Translating
        ) {
            current.connectedAtMs ?: clock()
        } else {
            current.connectedAtMs
        }
        mutableState.value = current.copy(phase = phase, connectedAtMs = connectedAt)
        AppFileLogger.i(LogTag, "event=phase callId=${current.callId} phase=$phase")
    }

    private fun appendTranscript(item: TranslationCallTranscriptItem) {
        val current = mutableState.value
        if (current.environment?.overallStatus == TranslationEnvironmentState.Unavailable) {
            AppFileLogger.i(
                LogTag,
                "event=subtitle_drop callId=${current.callId} " +
                    "provider=${current.plan?.provider} reason=environment_unavailable " +
                    "segmentTail=${item.segmentId.takeLast(8)} sourceLeg=${item.sourceLeg} " +
                    "final=${item.final} sourceLen=${item.sourceText.length} " +
                    "translatedLen=${item.translatedText.length}"
            )
            return
        }
        val index = current.transcripts.indexOfFirst {
            it.segmentId == item.segmentId && it.sourceLeg == item.sourceLeg
        }
        val updated = if (index < 0) {
            current.transcripts + item
        } else {
            current.transcripts.toMutableList().apply { set(index, item) }
        }
        AppFileLogger.i(
            LogTag,
            "event=subtitle_apply callId=${current.callId} provider=${current.plan?.provider} " +
                "action=${if (index < 0) "append" else "replace"} " +
                "segmentTail=${item.segmentId.takeLast(8)} sourceLeg=${item.sourceLeg} " +
                "final=${item.final} before=${current.transcripts.size} after=${updated.size} " +
                "sourceLen=${item.sourceText.length} translatedLen=${item.translatedText.length} " +
                "sourceHash=${item.sourceText.logHash()} " +
                "translatedHash=${item.translatedText.logHash()}"
        )
        mutableState.value = current.copy(transcripts = updated)
    }

    private fun finish(
        callId: String,
        success: Boolean,
        reason: String,
        failureKind: CallFailureKind = CallFailureKind.UNKNOWN
    ) {
        if (callId != mutableState.value.callId) return
        if (!terminalHandled.compareAndSet(false, true)) return
        val current = mutableState.value
        mutableState.value = current.copy(
            phase = if (success) TranslationCallPhase.Ended else TranslationCallPhase.Failed,
            failureReason = reason,
            failureKind = failureKind
        )
        AppFileLogger.i(
            LogTag,
            "event=terminal callId=$callId success=$success failureKind=$failureKind " +
                "reason=${reason.take(120)}"
        )
        if (reason.isNotBlank()) {
            mutableEffects.tryEmit(TranslationCallUiEffect.ShowFailure(failureKind))
        }
        mutableEffects.tryEmit(TranslationCallUiEffect.Finished(callId, success))
    }

    private companion object {
        const val LogTag = "TranslationCall"
    }
}

private fun String.logHash(): String = Integer.toHexString(hashCode())
