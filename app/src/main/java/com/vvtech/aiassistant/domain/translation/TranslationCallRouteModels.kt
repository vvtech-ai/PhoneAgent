package com.vvtech.aiassistant.domain.translation

enum class TranslationRegionSource {
    LiveLocation,
    TrustedCache
}

sealed interface TranslationRegionState {
    object Resolving : TranslationRegionState

    data class Resolved(
        val countryIso: String,
        val source: TranslationRegionSource,
        val sampledAtMs: Long
    ) : TranslationRegionState {
        val isChina: Boolean
            get() = countryIso.equals("CN", ignoreCase = true)
    }

    data class Unavailable(val reason: String) : TranslationRegionState
}

enum class TranslationCallTransport {
    LocalSipDomestic,
    LocalSipInternational,
    BackendWebRtc
}

enum class TranslationRealtimeProvider {
    Qwen,
    Doubao,
    OpenAi,
    Gemini
}

enum class TranslationServiceRegion {
    Default,
    UnitedStates,
    Japan
}

data class TranslationCallPreferences(
    val domesticProvider: TranslationRealtimeProvider = TranslationRealtimeProvider.Qwen,
    val overseasProvider: TranslationRealtimeProvider = TranslationRealtimeProvider.Gemini,
    val domesticSipAccountId: String,
    val internationalSipAccountId: String,
    val serviceRegion: TranslationServiceRegion = TranslationServiceRegion.Default
)

data class TranslationCallPlan(
    val locationCountryIso: String,
    val locationSource: TranslationRegionSource,
    val targetE164: String,
    val transport: TranslationCallTransport,
    val provider: TranslationRealtimeProvider,
    val sipAccountId: String?,
    val serviceRegion: TranslationServiceRegion,
    val networkDialNumber: String = targetE164,
    val postConnectDtmf: String = ""
)

enum class TranslationCallPlanFailure {
    LocationUnavailable,
    InvalidNumber,
    InvalidDomesticProvider,
    InvalidOverseasProvider,
    MissingSipAccount
}

sealed interface TranslationCallPlanResult {
    data class Ready(val plan: TranslationCallPlan) : TranslationCallPlanResult
    data class Failed(
        val reason: TranslationCallPlanFailure,
        val detail: String
    ) : TranslationCallPlanResult
}
