package com.vvtech.aiassistant.features.assistant_calls

internal fun formatDialInputForDisplay(
    rawNumber: String,
    countryIso: String
): String {
    if (rawNumber.isBlank()) return ""
    if (rawNumber.any { it == '*' || it == '#' }) return rawNumber
    return formatNationalNumber(rawNumber.filter(Char::isDigit), countryIso)
}

internal fun formatDialHistoryNumberForDisplay(
    rawNumber: String,
    defaultCountryIso: String = "CN"
): String {
    val trimmed = rawNumber.trim()
    if (trimmed.isBlank()) return ""
    if (trimmed.any { it == '*' || it == '#' }) return trimmed
    val digits = trimmed.filter(Char::isDigit)
    if (digits.isBlank()) return trimmed
    val international = trimmed.startsWith("+") || trimmed.startsWith("00")
    if (!international) return formatNationalNumber(digits, defaultCountryIso)

    val internationalDigits = if (trimmed.startsWith("00")) {
        digits.removePrefix("00")
    } else {
        digits
    }
    val country = supportedDisplayCountries.firstOrNull {
        internationalDigits.startsWith(it.dialCodeDigits)
    }
    if (country == null) return "+${internationalDigits.chunked(4).joinToString(" ")}"

    val nationalNumber = internationalDigits.removePrefix(country.dialCodeDigits)
    val formattedNational = formatNationalNumber(nationalNumber, country.iso)
    return listOf(country.dialCode, formattedNational)
        .filter(String::isNotBlank)
        .joinToString(" ")
}

internal fun dialSubscriberNumberForDisplay(rawNumber: String): String {
    val trimmed = rawNumber.trim()
    val digits = trimmed.filter(Char::isDigit)
    if (digits.isBlank()) return ""
    if (!trimmed.startsWith("+") && !trimmed.startsWith("00")) return digits

    val internationalDigits = if (trimmed.startsWith("00")) {
        digits.removePrefix("00")
    } else {
        digits
    }
    val dialCode = supportedDisplayCountries
        .firstOrNull { internationalDigits.startsWith(it.dialCodeDigits) }
        ?.dialCodeDigits
        .orEmpty()
    return internationalDigits.removePrefix(dialCode)
}

private fun formatNationalNumber(digits: String, countryIso: String): String {
    if (digits.isBlank()) return ""
    val groups = when (countryIso.uppercase()) {
        "CN" -> listOf(3, 4, 4)
        "US" -> listOf(3, 3, 4)
        "JP" -> if (digits.startsWith("0")) listOf(3, 4, 4) else listOf(2, 4, 4)
        "SG" -> listOf(4, 4)
        else -> return digits.chunked(4).joinToString(" ")
    }
    return groupDigits(digits, groups)
}

private fun groupDigits(digits: String, groups: List<Int>): String {
    val chunks = mutableListOf<String>()
    var offset = 0
    groups.forEach { size ->
        if (offset >= digits.length) return@forEach
        val end = (offset + size).coerceAtMost(digits.length)
        chunks += digits.substring(offset, end)
        offset = end
    }
    if (offset < digits.length) chunks += digits.substring(offset)
    return chunks.joinToString(" ")
}

private data class DisplayCountry(
    val iso: String,
    val dialCode: String
) {
    val dialCodeDigits: String = dialCode.removePrefix("+")
}

private val supportedDisplayCountries = listOf(
    DisplayCountry("CN", "+86"),
    DisplayCountry("JP", "+81"),
    DisplayCountry("SG", "+65"),
    DisplayCountry("US", "+1")
)
