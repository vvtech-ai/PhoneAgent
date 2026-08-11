package com.vvtech.aiassistant.domain.translation

import com.vvtech.aiassistant.domain.modelquality.ModelLatencyStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationModelNetworkQualityPolicyTest {
    @Test
    fun `latency thresholds use shared green yellow and orange states`() {
        assertEquals(ModelLatencyStatus.GOOD, status(199))
        assertEquals(ModelLatencyStatus.FAIR, status(200))
        assertEquals(ModelLatencyStatus.FAIR, status(499))
        assertEquals(ModelLatencyStatus.HIGH, status(500))
    }

    @Test
    fun `unavailable wins even when a failed probe has latency`() {
        val component = TranslationEnvironmentComponent(
            state = TranslationEnvironmentState.Unavailable,
            latencyMs = 800
        )
        assertEquals(
            ModelLatencyStatus.UNAVAILABLE,
            TranslationModelNetworkQualityPolicy.reading(component).status
        )
    }

    @Test
    fun `china only probes domestic providers`() {
        val components = TranslationModelNetworkQualityPolicy.initialComponents(
            TranslationRegionState.Resolved(
                countryIso = "CN",
                source = TranslationRegionSource.LiveLocation,
                sampledAtMs = 1
            )
        )
        assertEquals(
            TranslationEnvironmentState.Pending,
            components.getValue(TranslationRealtimeProvider.Qwen).state
        )
        assertEquals(
            TranslationEnvironmentState.Unavailable,
            components.getValue(TranslationRealtimeProvider.OpenAi).state
        )
    }

    @Test
    fun `overseas only probes overseas providers`() {
        val available = TranslationModelNetworkQualityPolicy.availableProviders(
            TranslationRegionState.Resolved(
                countryIso = "US",
                source = TranslationRegionSource.LiveLocation,
                sampledAtMs = 1
            )
        )
        assertTrue(TranslationRealtimeProvider.OpenAi in available)
        assertTrue(TranslationRealtimeProvider.Gemini in available)
        assertEquals(2, available.size)
    }

    private fun status(latencyMs: Long): ModelLatencyStatus =
        TranslationModelNetworkQualityPolicy.reading(
            TranslationEnvironmentComponent(
                state = TranslationEnvironmentState.Available,
                latencyMs = latencyMs
            )
        ).status
}
