package com.vvtech.aiassistant.features.assistant_calls

internal const val MaxDialNationalDigits = 14

internal sealed interface ContactDialNumberResult {
    data class Supported(
        val countryIso: String,
        val nationalNumber: String
    ) : ContactDialNumberResult

    object UnsupportedCountry : ContactDialNumberResult
    object TooLong : ContactDialNumberResult
    object Invalid : ContactDialNumberResult
}

internal fun parseContactDialNumber(
    raw: String,
    defaultCountryIso: String
): ContactDialNumberResult {
    val trimmed = raw.trim()
    if (trimmed.any { !it.isDigit() && it !in AllowedDialSeparators }) {
        return ContactDialNumberResult.Invalid
    }
    if ('+' in trimmed.drop(1)) return ContactDialNumberResult.Invalid
    val international = trimmed.startsWith("+") || trimmed.startsWith("00")
    val digits = trimmed.filter(Char::isDigit)
    if (digits.isBlank()) return ContactDialNumberResult.Invalid
    if (!international) return supportedNationalNumber(defaultCountryIso, digits)

    val withoutPrefix = if (trimmed.startsWith("00")) digits.removePrefix("00") else digits
    return when {
        withoutPrefix.startsWith("86") -> {
            val national = withoutPrefix.removePrefix("86")
            val chinaNational = if (
                national.length in 9..11 &&
                !Regex("1[3-9]\\d{9}").matches(national)
            ) {
                "0$national"
            } else {
                national
            }
            supportedNationalNumber("CN", chinaNational)
        }
        withoutPrefix.startsWith("65") ->
            supportedNationalNumber("SG", withoutPrefix.removePrefix("65"))
        withoutPrefix.startsWith("81") ->
            supportedNationalNumber("JP", withoutPrefix.removePrefix("81"))
        withoutPrefix.startsWith("1") ->
            parseNanpNumber(withoutPrefix.removePrefix("1"))
        else -> ContactDialNumberResult.UnsupportedCountry
    }
}

private fun supportedNationalNumber(
    countryIso: String,
    digits: String
): ContactDialNumberResult {
    val normalizedIso = countryIso.uppercase()
    if (normalizedIso !in SupportedDialCountryIsos) {
        return ContactDialNumberResult.UnsupportedCountry
    }
    if (digits.length > MaxDialNationalDigits) return ContactDialNumberResult.TooLong
    if (digits.isBlank()) return ContactDialNumberResult.Invalid
    return ContactDialNumberResult.Supported(normalizedIso, digits)
}

private fun parseNanpNumber(nationalNumber: String): ContactDialNumberResult {
    if (nationalNumber.length != 10) return ContactDialNumberResult.Invalid
    if (nationalNumber[0] !in '2'..'9' || nationalNumber[3] !in '2'..'9') {
        return ContactDialNumberResult.Invalid
    }
    val areaCode = nationalNumber.take(3).toIntOrNull()
        ?: return ContactDialNumberResult.Invalid
    return if (areaCode in CanadianAreaCodes) {
        ContactDialNumberResult.UnsupportedCountry
    } else {
        ContactDialNumberResult.Supported("US", nationalNumber)
    }
}

private val SupportedDialCountryIsos = setOf("CN", "SG", "JP", "US")
private val AllowedDialSeparators = setOf('+', ' ', '-', '(', ')', '.')

private val CanadianAreaCodes = setOf(
    204, 226, 236, 249, 250, 257, 263, 273, 289, 306, 343, 354, 365, 367,
    368, 382, 403, 416, 418, 428, 431, 437, 438, 450, 468, 474, 506, 514,
    519, 548, 579, 581, 584, 587, 600, 604, 613, 622, 633, 639, 647, 672,
    683, 705, 709,
    742, 753, 778, 780, 782, 807, 819, 825, 867, 873, 879, 902, 905, 942
)
