package com.vvtech.aiassistant.features.translation_call.state

import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityPolicy
import com.vvtech.aiassistant.domain.translation.TranslationModelNetworkQualityState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.data.TranslationModelEndpointProbe
import com.vvtech.aiassistant.features.translation_call.data.TranslationModelNetworkProbe
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope

internal class TranslationModelNetworkQualityCoordinator(
    private val probe: TranslationModelNetworkProbe = TranslationModelEndpointProbe()
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _state = MutableStateFlow(TranslationModelNetworkQualityState())
    val state: StateFlow<TranslationModelNetworkQualityState> = _state.asStateFlow()

    @Volatile
    private var generation = 0L

    @Volatile
    private var currentContext: QualityContext? = null

    fun updateContext(
        region: TranslationRegionState,
        serviceRegion: TranslationServiceRegion
    ) {
        val next = QualityContext(region, serviceRegion)
        if (currentContext?.key == next.key) return
        currentContext = next
        start(next, preserveAvailableSamples = false)
    }

    fun refresh() {
        val context = currentContext ?: return
        if (_state.value.refreshing) return
        start(context, preserveAvailableSamples = true)
    }

    fun release() {
        generation += 1
        scope.cancel()
    }

    private fun start(context: QualityContext, preserveAvailableSamples: Boolean) {
        val available = TranslationModelNetworkQualityPolicy.availableProviders(context.region)
        val batchId = ++generation
        val initial = TranslationModelNetworkQualityPolicy.initialComponents(context.region)
            .toMutableMap()
        if (preserveAvailableSamples) {
            available.forEach { provider ->
                _state.value.components[provider]?.let { initial[provider] = it }
            }
        }
        _state.value = TranslationModelNetworkQualityState(
            refreshing = available.isNotEmpty(),
            components = initial,
            sampledAtMs = if (preserveAvailableSamples) _state.value.sampledAtMs else 0L
        )
        if (available.isEmpty()) return
        scope.launch {
            val results = supervisorScope {
                available.associateWith { provider ->
                    async {
                        runCatching {
                            probe.probe(provider, context.serviceRegion)
                        }.fold(
                            onSuccess = ::normalizeCompletedProbe,
                            onFailure = { throwable ->
                                unavailableProbe(
                                    detail = "PROBE_EXCEPTION:${throwable.javaClass.simpleName}"
                                )
                            }
                        )
                    }
                }.mapValues { (_, deferred) -> deferred.await() }
            }
            if (generation != batchId || currentContext?.key != context.key) return@launch
            val completed = TranslationModelNetworkQualityPolicy.initialComponents(context.region)
                .toMutableMap()
                .apply { putAll(results) }
            _state.value = TranslationModelNetworkQualityState(
                refreshing = false,
                components = completed,
                sampledAtMs = System.currentTimeMillis()
            )
        }
    }

    private fun normalizeCompletedProbe(
        component: TranslationEnvironmentComponent
    ): TranslationEnvironmentComponent {
        val available = component.state == TranslationEnvironmentState.Available ||
            component.state == TranslationEnvironmentState.Degraded
        return if (available && component.latencyMs != null && component.latencyMs >= 0L) {
            component
        } else {
            unavailableProbe(component.detail ?: "NO_VALID_LATENCY")
        }
    }

    private fun unavailableProbe(detail: String): TranslationEnvironmentComponent =
        TranslationEnvironmentComponent(
            state = TranslationEnvironmentState.Unavailable,
            detail = detail
        )

    private data class QualityContext(
        val region: TranslationRegionState,
        val serviceRegion: TranslationServiceRegion
    ) {
        val key: String = when (region) {
            is TranslationRegionState.Resolved ->
                if (region.isChina) "CN" else "OVERSEAS:$serviceRegion"
            TranslationRegionState.Resolving -> "RESOLVING"
            is TranslationRegionState.Unavailable -> "UNAVAILABLE"
        }
    }
}
