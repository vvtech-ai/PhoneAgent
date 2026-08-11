package com.vvtech.aiassistant.callengine

import android.content.Context
import android.util.Log
import com.vvtech.aiassistant.domain.call.CallFailureClassifier
import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

internal class AndroidAssistantSipCallSession(
    private val context: Context,
    private val request: AssistantCallRequest,
    private val account: AssistantSipAccount,
    private val onEvent: (AssistantCallEngineEvent) -> Unit
) {
    private val active = AtomicBoolean(true)
    private val terminal = AtomicBoolean(false)
    private val desiredMuted = AtomicBoolean(false)
    private val muteLock = Any()
    private var socket: AssistantSipSocket? = null
    private var transactions: AssistantSipTransactions? = null
    private var media: AndroidSipMediaBridge? = null
    private var terminalFailure = ""
    private var terminalSipMethod: String? = null
    private var terminalSipStatusCode: Int? = null
    private var terminalFailureKind = CallFailureKind.UNKNOWN
    private val traceId = newSessionId().take(8)

    fun run() {
        try {
            log(
                "start",
                "mode=${request.mode} dialCode=${request.countryDialCode} configured=${account.configured}"
            )
            val sipSocket = AssistantSipSocket(account)
            socket = sipSocket
            val dialTarget = AssistantSipDialNumberFormatter.toDialNumber(
                request.phoneNumber,
                request.countryDialCode
            )
            val sipTransactions = AssistantSipTransactions(
                account = account,
                target = dialTarget,
                socket = sipSocket,
                active = active::get,
                onPhase = ::emitPhase
            )
            transactions = sipTransactions
            sipTransactions.register()
            log("registered")
            if (!active.get()) return
            val established = sipTransactions.invite()
            log(
                "answered",
                "codec=${established.endpoint.codec} payload=${established.endpoint.payloadType}"
            )
            if (!active.get()) return
            startMedia(sipSocket, established.endpoint)
            emitPhase(AssistantCallPhase.CONNECTED)
            if (request.mode == AssistantCallMode.TRANSLATION) {
                emitPhase(AssistantCallPhase.TRANSLATING)
            }
            sipTransactions.holdUntilEnded()
            log("remote_ended")
        } catch (error: Exception) {
            if (active.get()) {
                terminalFailure = error.message ?: "客户端 SIP 呼叫失败"
                val sipError = error as? AssistantSipResponseException
                terminalSipMethod = sipError?.sipMethod
                terminalSipStatusCode = sipError?.statusCode
                terminalFailureKind = if (sipError != null) {
                    CallFailureClassifier.fromSip(sipError.sipMethod, sipError.statusCode)
                } else {
                    CallFailureClassifier.fromThrowable(error)
                }
                Log.w(Tag, "CALL_TRACE id=$traceId stage=failed reason=$terminalFailure", error)
            }
        } finally {
            active.set(false)
            closeResources()
            if (terminalFailure.isBlank()) {
                finish(AssistantCallEngineEvent.Ended)
            } else {
                finish(
                    AssistantCallEngineEvent.Failure(
                        message = terminalFailure,
                        sipMethod = terminalSipMethod,
                        sipStatusCode = terminalSipStatusCode,
                        failureKind = terminalFailureKind
                    )
                )
            }
        }
    }

    fun setMuted(muted: Boolean) {
        synchronized(muteLock) {
            desiredMuted.set(muted)
            val activeMedia = media
            if (activeMedia == null) {
                fileLog("event=mute_deferred traceId=$traceId muted=$muted reason=media_not_ready")
                return
            }
            activeMedia.setMuted(muted)
            fileLog("event=mute_applied traceId=$traceId muted=$muted reason=media_ready")
        }
    }

    fun setSpeakerEnabled(enabled: Boolean) {
        media?.setSpeakerEnabled(enabled)
    }

    fun sendDtmf(digit: Char) {
        if (digit !in "0123456789*#") return
        val sentAsRtp = runCatching { media?.sendDtmf(digit) == true }.getOrDefault(false)
        log("dtmf", "route=${if (sentAsRtp) "rtp" else "sip_info"}")
        if (!sentAsRtp) transactions?.sendDtmf(digit)
    }

    fun hangup() {
        log("hangup_requested")
        transactions?.sendBye()
        active.set(false)
        closeResources()
    }

    private fun startMedia(
        sipSocket: AssistantSipSocket,
        endpoint: AssistantSipRemoteAudioEndpoint
    ) {
        var bridge: AndroidSipMediaBridge? = null
        val translator = if (request.mode == AssistantCallMode.TRANSLATION) {
            AssistantTranslationProcessorFactory.create(
                provider = request.provider,
                myLanguage = request.myLanguage,
                peerLanguage = request.peerLanguage,
                callbacks = AssistantTranslationProcessorCallbacks(
                    onTranscript = onTranscript@{
                        if (bridge?.shouldSuppressTranslationIntroOutput() == true) {
                            return@onTranscript
                        }
                        onEvent(
                            AssistantCallEngineEvent.Transcript(
                                id = it.id,
                                role = it.speaker,
                                sourceLanguage = it.sourceLanguage,
                                sourceText = it.sourceText,
                                translatedLanguage = it.translatedLanguage,
                                translatedText = it.translatedText,
                                final = it.final
                            )
                        )
                    },
                    onTranslatedAudioToSip = { bridge?.sendTranslatedPcm16kToSip(it) },
                    onTranslatedAudioToLocal = { bridge?.playTranslatedPcm16kLocally(it) },
                    onTranslatedAudioToSipCompleted = {
                        bridge?.markTranslatedAudioCompleted(toSip = true)
                    },
                    onTranslatedAudioToLocalCompleted = {
                        bridge?.markTranslatedAudioCompleted(toSip = false)
                    },
                    onError = ::failMedia,
                    onReady = {
                        bridge?.markTranslationIntroModelReady()
                        onEvent(AssistantCallEngineEvent.ModelReady)
                    }
                )
            )
        } else {
            null
        }
        bridge = AndroidSipMediaBridge(
            context = context,
            socket = sipSocket.media,
            endpoint = endpoint,
            translator = translator,
            traceId = traceId,
            playOriginalAudio = request.playOriginalAudio,
            originalAudioGainPercent = request.originalAudioGainPercent,
            originalAudioVolumePercent = request.originalAudioVolumePercent,
            initialSpeakerEnabled = true,
            translationIntroSpec = if (AssistantTranslationConnectPromptPolicy.isEnabled(request.mode)) {
                AssistantTranslationIntroSpec(
                    callerLanguage = request.myLanguage,
                    calleeLanguage = request.peerLanguage,
                    provider = request.provider,
                    traceId = traceId
                )
            } else {
                null
            },
            onFailure = ::failMedia
        )
        synchronized(muteLock) {
            media = bridge
            val initialMuted = desiredMuted.get()
            bridge.setMuted(initialMuted)
            fileLog("event=mute_applied traceId=$traceId muted=$initialMuted reason=media_start")
        }
        bridge.start()
    }

    private fun failMedia(message: String) {
        if (!active.getAndSet(false)) return
        terminalFailure = message
        Log.w(Tag, "CALL_TRACE id=$traceId stage=media_failed reason=$message")
        transactions?.sendBye()
        closeResources()
    }

    private fun emitPhase(phase: AssistantCallPhase) {
        log("phase", "value=$phase")
        if (!terminal.get()) onEvent(AssistantCallEngineEvent.PhaseChanged(phase))
    }

    private fun finish(event: AssistantCallEngineEvent) {
        if (terminal.compareAndSet(false, true)) {
            log("terminal", "type=${event::class.java.simpleName}")
            onEvent(event)
        }
    }

    private fun log(stage: String, detail: String = "") {
        val suffix = detail.takeIf(String::isNotBlank)?.let { " $it" }.orEmpty()
        Log.i(Tag, "CALL_TRACE id=$traceId stage=$stage$suffix")
    }

    private fun fileLog(message: String) {
        AppFileLogger.i(FileLogTag, message)
    }

    @Synchronized
    private fun closeResources() {
        runCatching { media?.close() }
        runCatching { socket?.close() }
        media = null
        socket = null
    }

    companion object {
        private const val Tag = "AssistantSipCall"
        private const val FileLogTag = "CLIENT_SIP_CALL"

        fun newSessionId(): String = UUID.randomUUID().toString()
    }
}
