package com.vvtech.aiassistant.model

data class RealtimeCallModelLatencyItem(
    val provider: String,
    val modelCode: String? = null,
    val modelName: String,
    val latencyMs: Long? = null,
    val available: Boolean,
    val status: String,
    val detail: String? = null,
    val probedAt: String? = null
)

data class RealtimeCallModelLatencyResponse(
    val models: List<RealtimeCallModelLatencyItem>,
    val probedAt: String? = null,
    val cacheTtlMs: Long = 0L,
    val cached: Boolean = false
)
