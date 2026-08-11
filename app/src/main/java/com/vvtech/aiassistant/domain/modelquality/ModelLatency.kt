package com.vvtech.aiassistant.domain.modelquality

enum class ModelLatencyStatus {
    UNKNOWN,
    GOOD,
    FAIR,
    HIGH,
    UNAVAILABLE
}

data class ModelLatencyReading(
    val status: ModelLatencyStatus = ModelLatencyStatus.UNKNOWN,
    val latencyMs: Long? = null
)

object ModelLatencyPolicy {
    const val GoodUpperBoundMs = 200L
    const val FairUpperBoundMs = 500L

    fun fromProbe(
        available: Boolean,
        latencyMs: Long?
    ): ModelLatencyReading {
        if (!available || latencyMs == null || latencyMs < 0L) {
            return ModelLatencyReading(ModelLatencyStatus.UNAVAILABLE)
        }
        return ModelLatencyReading(
            status = when {
                latencyMs < GoodUpperBoundMs -> ModelLatencyStatus.GOOD
                latencyMs < FairUpperBoundMs -> ModelLatencyStatus.FAIR
                else -> ModelLatencyStatus.HIGH
            },
            latencyMs = latencyMs
        )
    }

    fun unavailable(): ModelLatencyReading =
        ModelLatencyReading(ModelLatencyStatus.UNAVAILABLE)
}
