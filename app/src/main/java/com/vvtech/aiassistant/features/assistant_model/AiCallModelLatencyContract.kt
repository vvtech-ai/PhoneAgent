package com.vvtech.aiassistant.features.assistant_model

import com.vvtech.aiassistant.domain.modelquality.ModelLatencyPolicy
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyReading
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyStatus

internal data class AiCallModelLatencyState(
    val readings: Map<String, ModelLatencyReading> = emptyMap(),
    val refreshing: Boolean = false
) {
    fun readingOf(modelId: String): ModelLatencyReading =
        readings[modelId] ?: ModelLatencyReading()

    fun statusOf(modelId: String): ModelLatencyStatus =
        readingOf(modelId).status

    fun startRefresh(): AiCallModelLatencyState = copy(refreshing = true)

    fun completeRefresh(
        requestedModelIds: List<String>,
        effectiveResults: Map<String, ModelLatencyReading>
    ): AiCallModelLatencyState {
        val refreshed = requestedModelIds.associateWith { modelId ->
            effectiveResults.readingFor(modelId)
                ?.takeIf { it.status in availableStatuses && it.latencyMs != null }
                ?.let { ModelLatencyPolicy.fromProbe(available = true, latencyMs = it.latencyMs) }
                ?: ModelLatencyPolicy.unavailable()
        }
        return copy(readings = readings + refreshed, refreshing = false)
    }
}

internal fun interface AiCallModelLatencySource {
    suspend fun refresh(modelIds: List<String>): Map<String, ModelLatencyReading>
}

internal object PendingBackendAiCallModelLatencySource : AiCallModelLatencySource {
    override suspend fun refresh(
        modelIds: List<String>
    ): Map<String, ModelLatencyReading> = emptyMap()
}

internal fun aiCallModelLatencyReading(
    available: Boolean,
    latencyMs: Long?
): ModelLatencyReading = ModelLatencyPolicy.fromProbe(available, latencyMs)

private val availableStatuses = setOf(
    ModelLatencyStatus.GOOD,
    ModelLatencyStatus.FAIR,
    ModelLatencyStatus.HIGH
)

private fun Map<String, ModelLatencyReading>.readingFor(modelId: String): ModelLatencyReading? {
    this[modelId]?.let { return it }
    if (!modelId.equals(QWEN_OMNI_PLUS, ignoreCase = true)) {
        return null
    }
    return entries.firstOrNull {
        it.key.equals(LEGACY_QWEN_OMNI_FLASH, ignoreCase = true)
    }?.value
}

private const val QWEN_OMNI_PLUS = "QWEN_OMNI_PLUS"
private const val LEGACY_QWEN_OMNI_FLASH = "QWEN_OMNI_FLASH"
