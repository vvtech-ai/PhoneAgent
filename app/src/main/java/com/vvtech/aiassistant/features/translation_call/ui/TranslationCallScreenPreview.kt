package com.vvtech.aiassistant.features.translation_call.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironment
import com.vvtech.aiassistant.domain.translation.TranslationCallPlan
import com.vvtech.aiassistant.domain.translation.TranslationCallTransport
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallPhase
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallUiState

@Preview(name = "Realtime translation preflight", showBackground = true)
@Composable
private fun TranslationCallPreflightPreview() {
    TranslationCallScreen(
        state = previewState(
            phase = TranslationCallPhase.Preflight,
            environmentState = TranslationEnvironmentState.Pending
        ),
        onAction = {}
    )
}

@Preview(name = "Realtime translation connected", showBackground = true)
@Composable
private fun TranslationCallConnectedPreview() {
    TranslationCallScreen(
        state = previewState(
            phase = TranslationCallPhase.Translating,
            environmentState = TranslationEnvironmentState.Available
        ).copy(
            elapsedSeconds = 65,
            transcripts = listOf(
                TranslationCallTranscriptItem(
                    segmentId = "preview-1",
                    sourceLeg = "user",
                    sourceLanguage = "zh-CN",
                    sourceText = "您好，我想确认明天的预约。",
                    translatedLanguage = "en-US",
                    translatedText = "Hello, I would like to confirm tomorrow's reservation.",
                    final = true
                )
            )
        ),
        onAction = {}
    )
}

private fun previewState(
    phase: TranslationCallPhase,
    environmentState: TranslationEnvironmentState
) = TranslationCallUiState(
    callId = "preview",
    plan = TranslationCallPlan(
        locationCountryIso = "CN",
        locationSource = TranslationRegionSource.LiveLocation,
        targetE164 = "+8613800138000",
        transport = TranslationCallTransport.LocalSipDomestic,
        provider = TranslationRealtimeProvider.Qwen,
        sipAccountId = "21311780",
        serviceRegion = TranslationServiceRegion.Default
    ),
    phase = phase,
    environment = TranslationCallEnvironment(
        version = 1,
        phase = phase.name.lowercase(),
        overallStatus = environmentState,
        network = TranslationEnvironmentComponent(environmentState),
        sip = TranslationEnvironmentComponent(environmentState),
        model = TranslationEnvironmentComponent(environmentState),
        riskMessage = null,
        sampledAtMs = 1L
    )
)
