package com.vvtech.aiassistant.domain.translation

import com.vvtech.aiassistant.domain.phone.DialPhoneNumberPolicy
import com.vvtech.aiassistant.domain.phone.DialPhoneTarget
import com.vvtech.aiassistant.domain.phone.DialPhoneTargetResult

object TranslationCallRoutePolicy {
    private val domesticProviders = setOf(
        TranslationRealtimeProvider.Qwen,
        TranslationRealtimeProvider.Doubao
    )
    private val overseasProviders = setOf(
        TranslationRealtimeProvider.OpenAi,
        TranslationRealtimeProvider.Gemini
    )

    fun plan(
        region: TranslationRegionState,
        rawNumber: String,
        defaultCountryDialCode: String,
        preferences: TranslationCallPreferences,
        countryIso: String = ""
    ): TranslationCallPlanResult {
        val resolved = region as? TranslationRegionState.Resolved
            ?: return TranslationCallPlanResult.Failed(
                TranslationCallPlanFailure.LocationUnavailable,
                when (region) {
                    TranslationRegionState.Resolving -> "正在获取当前位置"
                    is TranslationRegionState.Unavailable -> region.reason
                    is TranslationRegionState.Resolved -> error("unreachable")
                }
            )
        val target = when (
            val result = DialPhoneNumberPolicy.resolve(
                countryIso = countryIso.ifBlank {
                    countryIsoForDialCode(defaultCountryDialCode)
                },
                countryDialCode = defaultCountryDialCode,
                rawNumber = rawNumber
            )
        ) {
            is DialPhoneTargetResult.Ready -> result.target
            is DialPhoneTargetResult.Invalid -> return TranslationCallPlanResult.Failed(
                TranslationCallPlanFailure.InvalidNumber,
                result.message
            )
        }
        return if (resolved.isChina) {
            domesticPlan(resolved, target, preferences)
        } else {
            overseasPlan(resolved, target, preferences)
        }
    }

    fun normalizeE164(rawNumber: String, defaultCountryDialCode: String): String? {
        if (rawNumber.count { it == '+' } > 1) return null
        return (
            DialPhoneNumberPolicy.resolve(
                countryIso = countryIsoForDialCode(defaultCountryDialCode),
                countryDialCode = defaultCountryDialCode,
                rawNumber = rawNumber
            ) as? DialPhoneTargetResult.Ready
            )?.target?.canonicalNumber?.takeIf { it.startsWith("+") }
    }

    private fun domesticPlan(
        region: TranslationRegionState.Resolved,
        target: DialPhoneTarget,
        preferences: TranslationCallPreferences
    ): TranslationCallPlanResult {
        if (preferences.domesticProvider !in domesticProviders) {
            return TranslationCallPlanResult.Failed(
                TranslationCallPlanFailure.InvalidDomesticProvider,
                "中国境内实时翻译仅支持千问或豆包"
            )
        }
        val domesticNumber = target.chinaDomestic
        val accountId = if (domesticNumber) {
            preferences.domesticSipAccountId
        } else {
            preferences.internationalSipAccountId
        }
        if (accountId.isBlank()) {
            return TranslationCallPlanResult.Failed(
                TranslationCallPlanFailure.MissingSipAccount,
                if (domesticNumber) "请先选择国内 SIP 账号" else "请先选择国际 SIP 账号"
            )
        }
        return TranslationCallPlanResult.Ready(
            basePlan(
                region = region,
                target = target,
                transport = if (domesticNumber) {
                    TranslationCallTransport.LocalSipDomestic
                } else {
                    TranslationCallTransport.LocalSipInternational
                },
                provider = preferences.domesticProvider,
                accountId = accountId,
                serviceRegion = preferences.serviceRegion
            )
        )
    }

    private fun overseasPlan(
        region: TranslationRegionState.Resolved,
        target: DialPhoneTarget,
        preferences: TranslationCallPreferences
    ): TranslationCallPlanResult {
        if (preferences.overseasProvider !in overseasProviders) {
            return TranslationCallPlanResult.Failed(
                TranslationCallPlanFailure.InvalidOverseasProvider,
                "海外实时翻译仅支持 OpenAI 或 Gemini"
            )
        }
        return TranslationCallPlanResult.Ready(
            basePlan(
                region = region,
                target = target,
                transport = TranslationCallTransport.BackendWebRtc,
                provider = preferences.overseasProvider,
                accountId = null,
                serviceRegion = preferences.serviceRegion
            )
        )
    }

    private fun basePlan(
        region: TranslationRegionState.Resolved,
        target: DialPhoneTarget,
        transport: TranslationCallTransport,
        provider: TranslationRealtimeProvider,
        accountId: String?,
        serviceRegion: TranslationServiceRegion
    ) = TranslationCallPlan(
        locationCountryIso = region.countryIso.uppercase(),
        locationSource = region.source,
        targetE164 = target.canonicalNumber,
        transport = transport,
        provider = provider,
        sipAccountId = accountId,
        serviceRegion = serviceRegion,
        networkDialNumber = target.networkDialNumber,
        postConnectDtmf = target.postConnectDtmf
    )

    private fun countryIsoForDialCode(dialCode: String): String = when (
        dialCode.filter(Char::isDigit)
    ) {
        "86" -> "CN"
        "1" -> "US"
        "81" -> "JP"
        "65" -> "SG"
        else -> ""
    }
}
