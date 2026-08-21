package com.vvtech.aiassistant.features.assistant_settings

import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage

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

    fun label(appLanguage: AppLanguage): String =
        if (id == "auto" && appLanguage == AppLanguage.English) {
            "Assigned by server"
        } else {
            label
        }
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

internal fun domesticSipAccountLabel(
    accountId: String?,
    appLanguage: AppLanguage = AppLanguage.SimplifiedChinese
): String =
    AssistantDomesticSipAccountOptions.first {
        it.id == normalizeDomesticSipAccountId(accountId)
    }.label(appLanguage)

internal fun internationalSipAccountLabel(
    accountId: String?,
    appLanguage: AppLanguage = AppLanguage.SimplifiedChinese
): String =
    AssistantInternationalSipAccountOptions.first {
        it.id == normalizeInternationalSipAccountId(accountId)
    }.label(appLanguage)
