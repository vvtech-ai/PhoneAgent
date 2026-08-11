package com.vvtech.aiassistant.features.translation_call.backend

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.features.translation_call.model.TranslationServiceEndpointResolver
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionGateway
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest
import java.util.concurrent.Executors

internal class BackendTranslationCallGateway(
    context: Context
) : TranslationCallSessionGateway {
    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val endpointResolver = TranslationServiceEndpointResolver(
        defaultBaseUrl = BuildConfig.TRANSLATION_WEBRTC_DEFAULT_URL,
        unitedStatesBaseUrl = BuildConfig.TRANSLATION_WEBRTC_US_URL,
        japanBaseUrl = BuildConfig.TRANSLATION_WEBRTC_JP_URL
    )
    @Volatile private var session: BackendTranslationCallRuntimeSession? = null

    override fun start(
        request: TranslationCallSessionRequest,
        onEvent: (TranslationCallSessionEvent) -> Unit
    ) {
        session?.hangup()
        if (request.plan.transport != TranslationCallTransport.BackendWebRtc) {
            onEvent(
                TranslationCallSessionEvent.Failure(
                    request.callId,
                    "当前路由不是后端 WebRTC"
                )
            )
            return
        }
        val endpoint = endpointResolver.resolve(request.plan.serviceRegion)
        val next = BackendTranslationCallRuntimeSession(
            request = request,
            client = HttpBackendTranslationClient(endpoint.baseUrl),
            liveKit = BackendLiveKitAudioClient(appContext),
            appAudio = BackendAppAudioSocket(),
            audioBridge = AndroidBackendPcmAudioBridge(appContext),
            onEvent = { event -> mainHandler.post { onEvent(event) } }
        )
        session = next
        executor.execute {
            next.run()
            if (session === next) session = null
        }
    }

    override fun setMuted(muted: Boolean) {
        session?.setMuted(muted)
    }

    override fun setSpeakerEnabled(enabled: Boolean) {
        session?.setSpeakerEnabled(enabled)
    }

    override fun sendDtmf(digit: Char) = Unit

    override fun hangup() {
        session?.hangup()
    }

    override fun release() {
        session?.hangup()
        session = null
        executor.shutdownNow()
    }
}
