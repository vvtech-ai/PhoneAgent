package com.vvtech.aiassistant.features.translation_call.data

import android.content.Context
import com.vvtech.aiassistant.callengine.AndroidAssistantCallEngineGateway
import com.vvtech.aiassistant.callengine.AssistantCallEngineConfiguration
import com.vvtech.aiassistant.callengine.AssistantCallEngineEvent
import com.vvtech.aiassistant.callengine.AssistantCallEngineGateway
import com.vvtech.aiassistant.callengine.AssistantCallMode
import com.vvtech.aiassistant.callengine.AssistantCallPhase
import com.vvtech.aiassistant.callengine.AssistantCallRequest
import com.vvtech.aiassistant.domain.call.CallFailureKind
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionGateway
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest
import java.util.concurrent.atomic.AtomicLong

internal class LocalSipTranslationCallGateway(
    private val callEngine: AssistantCallEngineGateway,
    private val environmentMonitor: LocalTranslationEnvironmentMonitor,
    private val modelQualityProvider: () -> TranslationModelNetworkQualityState = {
        TranslationModelNetworkQualityState()
    }
) : TranslationCallSessionGateway {
    constructor(
        context: Context,
        modelQualityProvider: () -> TranslationModelNetworkQualityState = {
            TranslationModelNetworkQualityState()
        }
    ) : this(
        callEngine = AndroidAssistantCallEngineGateway(context),
        environmentMonitor = AndroidLocalTranslationEnvironmentMonitor(context),
        modelQualityProvider = modelQualityProvider
    )

    private val environmentVersion = AtomicLong()
    private var activeCallId = ""
    private var listener: ((TranslationCallSessionEvent) -> Unit)? = null
    private var connected = false
    private var autoDtmfSent = false
    private var postConnectDtmf = ""

    override fun start(
        request: TranslationCallSessionRequest,
        onEvent: (TranslationCallSessionEvent) -> Unit
    ) {
        environmentMonitor.stop()
        activeCallId = request.callId
        listener = onEvent
        connected = false
        autoDtmfSent = false
        postConnectDtmf = request.plan.postConnectDtmf
        val network = environmentMonitor.currentNetwork()
        val sip = configuredSipState(request)
        val model = configuredModelState(request)
        emitEnvironment(request.callId, "preflight", network, sip, model)
        val blockingReason = listOf(network, sip, model)
            .firstOrNull { it.state == TranslationEnvironmentState.Unavailable }
            ?.detail
        if (blockingReason != null) {
            emit(
                TranslationCallSessionEvent.Failure(
                    callId = request.callId,
                    message = blockingReason,
                    failureKind = CallFailureKind.NETWORK
                )
            )
            return
        }
        environmentMonitor.start { changed ->
            emitEnvironment(
                request.callId,
                if (connected) "connected" else "preflight",
                network = changed
            )
        }
        callEngine.start(request.toEngineRequest(), ::handleEngineEvent)
    }

    override fun setMuted(muted: Boolean) = callEngine.setMuted(muted)
    override fun setSpeakerEnabled(enabled: Boolean) = callEngine.setSpeakerEnabled(enabled)
    override fun sendDtmf(digit: Char) = callEngine.sendDtmf(digit)
    override fun hangup() = callEngine.hangup()

    override fun release() {
        environmentMonitor.stop()
        callEngine.release()
        activeCallId = ""
        listener = null
    }

    private fun handleEngineEvent(event: AssistantCallEngineEvent) {
        val callId = activeCallId
        if (callId.isBlank()) return
        when (event) {
            is AssistantCallEngineEvent.PhaseChanged -> handlePhase(callId, event.phase)
            is AssistantCallEngineEvent.Transcript -> emit(
                TranslationCallSessionEvent.Transcript(
                    callId,
                    com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem(
                        event.id,
                        event.role,
                        event.sourceLanguage,
                        event.sourceText,
                        event.translatedLanguage,
                        event.translatedText,
                        event.final
                    )
                )
            )
            AssistantCallEngineEvent.ModelReady -> emitEnvironment(
                callId,
                "translating",
                model = TranslationEnvironmentComponent(TranslationEnvironmentState.Available)
            )
            is AssistantCallEngineEvent.Failure -> {
                val failedComponent = TranslationEnvironmentComponent(
                    TranslationEnvironmentState.Unavailable
                )
                emitEnvironment(
                    callId,
                    "failed",
                    sip = if (connected) null else failedComponent,
                    model = if (connected) failedComponent else null
                )
                emit(
                    TranslationCallSessionEvent.Failure(
                        callId = callId,
                        message = event.message,
                        sipMethod = event.sipMethod,
                        sipStatusCode = event.sipStatusCode,
                        failureKind = event.failureKind
                    )
                )
                environmentMonitor.stop()
            }
            AssistantCallEngineEvent.Ended -> {
                emit(TranslationCallSessionEvent.Ended(callId))
                environmentMonitor.stop()
            }
        }
    }

    private fun handlePhase(callId: String, phase: AssistantCallPhase) {
        val translatedPhase = when (phase) {
            AssistantCallPhase.IDLE, AssistantCallPhase.REGISTERING ->
                TranslationCallPhase.Preflight
            AssistantCallPhase.DIALING -> TranslationCallPhase.Dialing
            AssistantCallPhase.RINGING -> TranslationCallPhase.Ringing
            AssistantCallPhase.CONNECTED -> TranslationCallPhase.Connected
            AssistantCallPhase.TRANSLATING -> TranslationCallPhase.Translating
            AssistantCallPhase.ENDED -> TranslationCallPhase.Ended
            AssistantCallPhase.FAILED -> TranslationCallPhase.Failed
        }
        if (phase == AssistantCallPhase.DIALING) {
            emitEnvironment(
                callId,
                "dialing",
                sip = TranslationEnvironmentComponent(TranslationEnvironmentState.Available)
            )
        }
        if (phase == AssistantCallPhase.CONNECTED || phase == AssistantCallPhase.TRANSLATING) {
            connected = true
            if (!autoDtmfSent && postConnectDtmf.isNotBlank()) {
                autoDtmfSent = true
                postConnectDtmf.forEach(callEngine::sendDtmf)
            }
        }
        emit(TranslationCallSessionEvent.PhaseChanged(callId, translatedPhase))
    }

    private fun configuredSipState(
        request: TranslationCallSessionRequest
    ): TranslationEnvironmentComponent {
        return if (request.plan.transport == TranslationCallTransport.BackendWebRtc) {
            TranslationEnvironmentComponent(
                TranslationEnvironmentState.Unavailable,
                detail = "WebRTC 通话暂未启用"
            )
        } else {
            TranslationEnvironmentComponent(TranslationEnvironmentState.Pending)
        }
    }

    private fun configuredModelState(
        request: TranslationCallSessionRequest
    ): TranslationEnvironmentComponent {
        val configured = when (request.plan.provider) {
            TranslationRealtimeProvider.Qwen -> AssistantCallEngineConfiguration.qwen().configured
            TranslationRealtimeProvider.Doubao -> AssistantCallEngineConfiguration.doubao().configured
            else -> false
        }
        if (!configured) {
            return TranslationEnvironmentComponent(
                TranslationEnvironmentState.Unavailable,
                detail = "${request.plan.provider} 实时翻译配置缺失"
            )
        }
        return modelQualityProvider().components[request.plan.provider]
            ?.takeUnless {
                it.state == TranslationEnvironmentState.Pending ||
                    it.state == TranslationEnvironmentState.NotApplicable
            }
            ?: TranslationEnvironmentComponent(TranslationEnvironmentState.Pending)
    }

    private fun TranslationCallSessionRequest.toEngineRequest() = AssistantCallRequest(
        phoneNumber = plan.networkDialNumber,
        countryDialCode = "",
        mode = AssistantCallMode.TRANSLATION,
        provider = plan.provider.name.lowercase(),
        myLanguage = myLanguage,
        peerLanguage = peerLanguage,
        playOriginalAudio = playOriginalAudio,
        originalAudioGainPercent = originalAudioGainPercent,
        originalAudioVolumePercent = originalAudioVolumePercent,
        selectedDomesticSipAccountId = plan.sipAccountId.orEmpty(),
        selectedInternationalSipAccountId = plan.sipAccountId.orEmpty()
    )

    private fun emitEnvironment(
        callId: String,
        phase: String,
        network: TranslationEnvironmentComponent? = null,
        sip: TranslationEnvironmentComponent? = null,
        model: TranslationEnvironmentComponent? = null
    ) {
        emit(
            TranslationCallSessionEvent.EnvironmentChanged(
                callId,
                TranslationCallEnvironmentPatch(
                    version = environmentVersion.incrementAndGet(),
                    phase = phase,
                    network = network,
                    sip = sip,
                    model = model,
                    riskMessage = listOfNotNull(network, sip, model)
                        .firstOrNull {
                            it.state == TranslationEnvironmentState.Degraded ||
                                it.state == TranslationEnvironmentState.Unavailable
                        }
                        ?.detail,
                    sampledAtMs = System.currentTimeMillis()
                )
            )
        )
    }

    private fun emit(event: TranslationCallSessionEvent) {
        if (event.callId == activeCallId) listener?.invoke(event)
    }
}
