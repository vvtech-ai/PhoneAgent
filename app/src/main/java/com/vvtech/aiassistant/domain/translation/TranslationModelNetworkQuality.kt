package com.vvtech.aiassistant.domain.translation

import com.vvtech.aiassistant.domain.modelquality.ModelLatencyPolicy
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyReading

data class TranslationModelNetworkQualityState(
    val refreshing: Boolean = false,
    val components: Map<TranslationRealtimeProvider, TranslationEnvironmentComponent> =
        TranslationRealtimeProvider.values().associateWith {
            TranslationEnvironmentComponent(TranslationEnvironmentState.Pending)
        },
    val sampledAtMs: Long = 0L
)

object TranslationModelNetworkQualityPolicy {
    fun availableProviders(
        region: TranslationRegionState
    ): Set<TranslationRealtimeProvider> = when (region) {
        is TranslationRegionState.Resolved -> if (region.isChina) {
            setOf(TranslationRealtimeProvider.Qwen, TranslationRealtimeProvider.Doubao)
        } else {
            setOf(TranslationRealtimeProvider.OpenAi, TranslationRealtimeProvider.Gemini)
        }
        else -> emptySet()
    }

    fun initialComponents(
        region: TranslationRegionState
    ): Map<TranslationRealtimeProvider, TranslationEnvironmentComponent> {
        val available = availableProviders(region)
        return TranslationRealtimeProvider.values().associateWith { provider ->
            if (provider in available) {
                TranslationEnvironmentComponent(TranslationEnvironmentState.Pending)
            } else {
                TranslationEnvironmentComponent(
                    state = TranslationEnvironmentState.Unavailable,
                    detail = "REGION_UNAVAILABLE"
                )
            }
        }
    }

    fun reading(component: TranslationEnvironmentComponent?): ModelLatencyReading {
        if (component == null || component.state == TranslationEnvironmentState.Pending) {
            return ModelLatencyReading()
        }
        val available = component.state == TranslationEnvironmentState.Available ||
            component.state == TranslationEnvironmentState.Degraded
        return ModelLatencyPolicy.fromProbe(
            available = available,
            latencyMs = component.latencyMs
        )
    }
}
