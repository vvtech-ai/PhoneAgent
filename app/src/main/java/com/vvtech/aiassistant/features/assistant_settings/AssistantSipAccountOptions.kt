package com.vvtech.aiassistant.features.assistant_settings

internal const val DefaultDomesticSipAccountId = "auto"
internal const val DefaultInternationalSipAccountId = "auto"
internal const val DomesticSipAccountPreferenceKey = "selected_domestic_sip_account_id"
internal const val InternationalSipAccountPreferenceKey = "selected_international_sip_account_id"

internal data class AssistantSipAccountOption(
    val id: String,
    val username: String,
    val displayName: String = ""
) {
    val label: String
        get() = displayName.trim().takeIf(String::isNotEmpty)
            ?.let { "$username（$it）" }
            ?: username
}

internal val AssistantDomesticSipAccountOptions = listOf(
    AssistantSipAccountOption(id = "auto", username = "后台自动分配")
)

internal val AssistantInternationalSipAccountOptions = listOf(
    AssistantSipAccountOption(id = "auto", username = "后台自动分配")
)

internal fun normalizeDomesticSipAccountId(rawId: String?): String =
    AssistantDomesticSipAccountOptions.firstOrNull { it.id == rawId?.trim() }?.id
        ?: DefaultDomesticSipAccountId

internal fun normalizeInternationalSipAccountId(rawId: String?): String =
    AssistantInternationalSipAccountOptions.firstOrNull { it.id == rawId?.trim() }?.id
        ?: DefaultInternationalSipAccountId

internal fun domesticSipAccountLabel(accountId: String?): String =
    AssistantDomesticSipAccountOptions.first {
        it.id == normalizeDomesticSipAccountId(accountId)
    }.label

internal fun internationalSipAccountLabel(accountId: String?): String =
    AssistantInternationalSipAccountOptions.first {
        it.id == normalizeInternationalSipAccountId(accountId)
    }.label
