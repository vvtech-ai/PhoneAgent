package com.vvtech.aiassistant.features.assistant_calls

internal data class DialTranslationLanguageCodes(
    val caller: String,
    val callee: String
)

internal fun dialTranslationLanguageCodes(
    myLanguage: String,
    otherLanguage: String
): DialTranslationLanguageCodes = DialTranslationLanguageCodes(
    caller = dialTranslationLanguageCode(myLanguage, fallback = "zh"),
    callee = dialTranslationLanguageCode(otherLanguage, fallback = "en")
)

private fun dialTranslationLanguageCode(label: String, fallback: String): String {
    return DialLanguageCodes[label.trim()] ?: fallback
}

internal fun dialTranslationLanguageLabel(code: String): String? =
    DialLanguageCodes.entries.firstOrNull { it.value == code.trim().lowercase() }?.key

internal fun doubaoTranslationLanguagePairRejectMessage(
    callerLanguageCode: String,
    calleeLanguageCode: String
): String? {
    val caller = normalizeTranslationLanguageCode(callerLanguageCode)
    val callee = normalizeTranslationLanguageCode(calleeLanguageCode)
    return if (caller in DoubaoSupportedLanguageCodes &&
        callee in DoubaoSupportedLanguageCodes &&
        (caller in DoubaoRequiredPivotLanguageCodes ||
            callee in DoubaoRequiredPivotLanguageCodes)
    ) {
        null
    } else {
        DoubaoUnsupportedLanguagePairMessage
    }
}

private val DialLanguageCodes = mapOf(
    "中文" to "zh",
    "英文" to "en",
    "葡萄牙语" to "pt",
    "日语" to "ja",
    "印尼语" to "id",
    "韩语" to "ko",
    "法语" to "fr",
    "德语" to "de",
    "西班牙语" to "es"
)

private val DoubaoSupportedLanguageCodes = setOf("zh", "en", "pt", "es", "ja", "id", "de", "fr")
private val DoubaoRequiredPivotLanguageCodes = setOf("zh", "en")
private const val DoubaoUnsupportedLanguagePairMessage =
    "豆包实时翻译暂不支持该语种组合，请选择中文或英语作为其中一种语言"

private fun normalizeTranslationLanguageCode(raw: String): String =
    raw.trim().lowercase().substringBefore('-').substringBefore('_')
