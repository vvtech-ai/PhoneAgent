package com.vvtech.aiassistant.domain.translation

enum class TranslationEnvironmentState {
    Pending,
    Available,
    Degraded,
    Unavailable,
    NotApplicable
}

data class TranslationEnvironmentComponent(
    val state: TranslationEnvironmentState,
    val latencyMs: Long? = null,
    val detail: String? = null
)

data class TranslationCallEnvironment(
    val version: Long,
    val phase: String,
    val overallStatus: TranslationEnvironmentState,
    val network: TranslationEnvironmentComponent,
    val sip: TranslationEnvironmentComponent,
    val model: TranslationEnvironmentComponent,
    val riskMessage: String?,
    val sampledAtMs: Long
)

data class TranslationCallEnvironmentPatch(
    val version: Long,
    val phase: String? = null,
    val network: TranslationEnvironmentComponent? = null,
    val sip: TranslationEnvironmentComponent? = null,
    val model: TranslationEnvironmentComponent? = null,
    val riskMessage: String? = null,
    val clearRiskMessage: Boolean = false,
    val sampledAtMs: Long? = null
)

internal fun pendingEnvironmentComponent() = TranslationEnvironmentComponent(
    state = TranslationEnvironmentState.Pending
)
