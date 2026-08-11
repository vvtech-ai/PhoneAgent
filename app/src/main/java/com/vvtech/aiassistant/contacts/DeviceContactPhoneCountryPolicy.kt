package com.vvtech.aiassistant.contacts

internal data class DeviceContactPhoneCountryValue(
    val lookupNumber: String,
    val dialNumber: String,
    val countryIso: String?,
    val dialCode: String?,
    val nationalNumber: String
)

internal object DeviceContactPhoneCountryPolicy {
    fun resolve(
        rawNumber: String,
        normalizedNumber: String?
    ): DeviceContactPhoneCountryValue? {
        val normalized = normalizedNumber.orEmpty().trim()
        val internationalSource = when {
            normalized.hasInternationalPrefix() -> normalized
            rawNumber.trim().hasInternationalPrefix() -> rawNumber.trim()
            else -> null
        }
        if (internationalSource != null) {
            return resolveInternational(internationalSource)
                ?.withLocalChinaLookup(rawNumber)
        }

        val localSource = normalized.takeIf(String::isNotBlank) ?: rawNumber
        val lookupNumber = DeviceContactPolicy.normalizePhone(localSource)
        if (lookupNumber.isBlank()) return null
        return DeviceContactPhoneCountryValue(
            lookupNumber = lookupNumber,
            dialNumber = "+86$lookupNumber",
            countryIso = "CN",
            dialCode = "+86",
            nationalNumber = lookupNumber
        )
    }

    private fun resolveInternational(rawNumber: String): DeviceContactPhoneCountryValue? {
        if (rawNumber.any { !it.isDigit() && it !in InternationalSeparators }) return null
        val digits = rawNumber.filter(Char::isDigit)
        val internationalDigits = if (rawNumber.trim().startsWith("00")) {
            digits.removePrefix("00")
        } else {
            digits
        }
        if (internationalDigits.isBlank()) return null

        val canonical = "+$internationalDigits"
        val country = SupportedCountries.firstOrNull {
            internationalDigits.startsWith(it.dialDigits)
        }
        if (country == null) {
            return DeviceContactPhoneCountryValue(
                lookupNumber = canonical,
                dialNumber = canonical,
                countryIso = null,
                dialCode = null,
                nationalNumber = internationalDigits
            )
        }

        val nationalNumber = internationalDigits.removePrefix(country.dialDigits)
        if (nationalNumber.isBlank()) return null
        return DeviceContactPhoneCountryValue(
            lookupNumber = if (country.iso == "CN") nationalNumber else canonical,
            dialNumber = canonical,
            countryIso = country.iso,
            dialCode = "+${country.dialDigits}",
            nationalNumber = nationalNumber
        )
    }

    private fun String.hasInternationalPrefix(): Boolean =
        startsWith("+") || startsWith("00")

    private fun DeviceContactPhoneCountryValue.withLocalChinaLookup(
        rawNumber: String
    ): DeviceContactPhoneCountryValue {
        if (countryIso != "CN" || rawNumber.trim().hasInternationalPrefix()) return this
        val localLookupNumber = DeviceContactPolicy.normalizePhone(rawNumber)
        return if (localLookupNumber.isBlank()) {
            this
        } else {
            copy(lookupNumber = localLookupNumber)
        }
    }

    private data class SupportedCountry(
        val iso: String,
        val dialDigits: String
    )

    private val SupportedCountries = listOf(
        SupportedCountry("CN", "86"),
        SupportedCountry("SG", "65"),
        SupportedCountry("JP", "81"),
        SupportedCountry("US", "1")
    )

    private val InternationalSeparators = setOf('+', ' ', '-', '(', ')', '（', '）', '.')
}
