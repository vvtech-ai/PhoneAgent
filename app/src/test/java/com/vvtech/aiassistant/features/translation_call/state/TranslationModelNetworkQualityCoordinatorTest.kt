package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.data.TranslationModelNetworkProbe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationModelNetworkQualityCoordinatorTest {
    @Test
    fun `china refresh only probes domestic providers`() = runBlocking {
        val requested = linkedSetOf<TranslationRealtimeProvider>()
        val coordinator = TranslationModelNetworkQualityCoordinator(
            TranslationModelNetworkProbe { provider, _ ->
                synchronized(requested) { requested += provider }
                TranslationEnvironmentComponent(
                    state = TranslationEnvironmentState.Available,
                    latencyMs = 146
                )
            }
        )
        try {
            coordinator.updateContext(china(), TranslationServiceRegion.Default)
            val completed = withTimeout(2_000) {
                coordinator.state.first { !it.refreshing && it.sampledAtMs > 0 }
            }
            assertEquals(
                setOf(TranslationRealtimeProvider.Qwen, TranslationRealtimeProvider.Doubao),
                requested
            )
            assertEquals(
                146L,
                completed.components.getValue(TranslationRealtimeProvider.Qwen).latencyMs
            )
            assertEquals(
                TranslationEnvironmentState.Unavailable,
                completed.components.getValue(TranslationRealtimeProvider.OpenAi).state
            )
        } finally {
            coordinator.release()
        }
    }

    @Test
    fun `unresolved region never starts a model probe`() {
        var invoked = false
        val coordinator = TranslationModelNetworkQualityCoordinator(
            TranslationModelNetworkProbe { _, _ ->
                invoked = true
                error("probe must not run")
            }
        )
        try {
            coordinator.updateContext(
                TranslationRegionState.Unavailable("定位不可用"),
                TranslationServiceRegion.Default
            )
            assertTrue(coordinator.state.value.components.values.all {
                it.state == TranslationEnvironmentState.Unavailable
            })
            assertEquals(false, invoked)
        } finally {
            coordinator.release()
        }
    }

    @Test
    fun `one provider exception does not block other provider result`() = runBlocking {
        val coordinator = TranslationModelNetworkQualityCoordinator(
            TranslationModelNetworkProbe { provider, _ ->
                if (provider == TranslationRealtimeProvider.Qwen) {
                    error("qwen timeout")
                }
                TranslationEnvironmentComponent(
                    state = TranslationEnvironmentState.Available,
                    latencyMs = 163
                )
            }
        )
        try {
            coordinator.updateContext(china(), TranslationServiceRegion.Default)
            val completed = withTimeout(2_000) {
                coordinator.state.first { !it.refreshing && it.sampledAtMs > 0 }
            }

            assertEquals(
                TranslationEnvironmentState.Unavailable,
                completed.components.getValue(TranslationRealtimeProvider.Qwen).state
            )
            assertEquals(
                TranslationEnvironmentState.Available,
                completed.components.getValue(TranslationRealtimeProvider.Doubao).state
            )
            assertEquals(
                163L,
                completed.components.getValue(TranslationRealtimeProvider.Doubao).latencyMs
            )
        } finally {
            coordinator.release()
        }
    }

    private fun china() = TranslationRegionState.Resolved(
        countryIso = "CN",
        source = TranslationRegionSource.LiveLocation,
        sampledAtMs = 1
    )
}
