package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import org.json.JSONObject

internal object BackendTranslationEnvironmentProtocol {
    fun parse(json: JSONObject?): TranslationCallEnvironmentPatch? {
        if (json == null) return null
        val version = (json.opt("version") as? Number)?.toLong() ?: return null
        if (version < 0) return null
        return TranslationCallEnvironmentPatch(
            version = version,
            phase = json.optionalString("phase"),
            network = parseComponent(json.optJSONObject("network")),
            sip = parseComponent(json.optJSONObject("sip")),
            model = parseComponent(json.optJSONObject("model")),
            riskMessage = json.optionalString("riskMessage"),
            sampledAtMs = (json.opt("sampledAtMs") as? Number)?.toLong()
        )
    }

    private fun parseComponent(json: JSONObject?): TranslationEnvironmentComponent? {
        val state = when (json?.optString("state")?.trim()?.lowercase()) {
            "available" -> TranslationEnvironmentState.Available
            "degraded" -> TranslationEnvironmentState.Degraded
            "unavailable" -> TranslationEnvironmentState.Unavailable
            "not_applicable", "not-applicable" -> TranslationEnvironmentState.NotApplicable
            "pending" -> TranslationEnvironmentState.Pending
            else -> return null
        }
        return TranslationEnvironmentComponent(
            state = state,
            latencyMs = (json.opt("latencyMs") as? Number)?.toLong(),
            detail = json.optionalString("detail")
        )
    }

    private fun JSONObject.optionalString(name: String): String? =
        (opt(name) as? String)?.trim()?.takeIf(String::isNotEmpty)
}
