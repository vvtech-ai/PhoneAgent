package com.vvtech.aiassistant.features.assistant_calls

internal data class DialCountry(
    val iso: String,
    val name: String,
    val dialCode: String,
    val flag: String,
    val section: Char,
    val pinyin: String,
    val initials: String,
    val g20: Boolean = false
)

internal val DialCountries = listOf(
    DialCountry("CN", "中国", "+86", "🇨🇳", 'C', "zhongguo", "zg", g20 = true),
    DialCountry("JP", "日本", "+81", "🇯🇵", 'J', "riben", "rb", g20 = true),
    DialCountry("SG", "新加坡", "+65", "🇸🇬", 'S', "xinjiapo", "xjp"),
    DialCountry("US", "美国", "+1", "🇺🇸", 'U', "meiguo", "mg", g20 = true)
)

internal fun dialCountryByIso(iso: String): DialCountry =
    DialCountries.firstOrNull { it.iso == iso.uppercase() }
        ?: DialCountries.first { it.iso == "CN" }

internal fun resolveLocatedDialCountry(iso: String?): DialCountry? {
    val normalized = iso?.trim()?.uppercase().orEmpty()
    return DialCountries.firstOrNull { it.iso == normalized }
}
