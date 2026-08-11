package com.vvtech.aiassistant.features.translation_call.data

import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionEvent
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionGateway
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSessionRequest

internal class RegionAwareTranslationCallGateway(
    private val localSip: TranslationCallSessionGateway,
    private val backendWebRtc: TranslationCallSessionGateway
) : TranslationCallSessionGateway {
    private var active: TranslationCallSessionGateway? = null

    override fun start(
        request: TranslationCallSessionRequest,
        onEvent: (TranslationCallSessionEvent) -> Unit
    ) {
        active?.hangup()
        active = when (request.plan.transport) {
            TranslationCallTransport.LocalSipDomestic,
            TranslationCallTransport.LocalSipInternational -> localSip
            TranslationCallTransport.BackendWebRtc -> backendWebRtc
        }
        active?.start(request, onEvent)
    }

    override fun setMuted(muted: Boolean) {
        active?.setMuted(muted)
    }

    override fun setSpeakerEnabled(enabled: Boolean) {
        active?.setSpeakerEnabled(enabled)
    }

    override fun sendDtmf(digit: Char) {
        active?.sendDtmf(digit)
    }

    override fun hangup() {
        active?.hangup()
    }

    override fun release() {
        active = null
        localSip.release()
        backendWebRtc.release()
    }
}
