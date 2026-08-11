package com.vvtech.aiassistant.domain.phone

internal object DialPhoneNumberPolicy {
    const val ChinaMobileValidationMessage = "请输入正确的手机号码"
    const val InvalidPhoneNumberMessage = "请输入正确的电话号码"

    private val ChinaMobilePattern = Regex("1[3-9]\\d{9}")
    private val ChinaFixedLinePattern = Regex("0\\d{2,3}\\d{7,8}")
    private val ChinaServicePattern =
        Regex("(?:400\\d{7}|800\\d{7}|95\\d{3,8}|96\\d{3,8}|1\\d{4})")
    private val ChinaLocalOrShortPattern = Regex("\\d{3,8}")
    private val ChinaEmergencyNumbers = setOf("110", "119", "120", "122")
    private val ExplicitExtensionPattern =
        Regex("(?i)(?:转|ext\\.?|x|#|\\*)\\s*(\\d{1,6})\\s*$")
    private val TrailingDashExtensionPattern = Regex("-\\s*(\\d{1,6})\\s*$")

    fun validationMessage(countryIso: String, nationalNumber: String): String? {
        if (!countryIso.equals("CN", ignoreCase = true)) return null
        return when (resolve(countryIso, "+86", nationalNumber)) {
            is DialPhoneTargetResult.Ready -> null
            is DialPhoneTargetResult.Invalid -> ChinaMobileValidationMessage
        }
    }

    fun systemDialValidationMessage(countryIso: String, nationalNumber: String): String? {
        if (nationalNumber.none(Char::isDigit)) return null
        return when (resolve(countryIso, countryDialCode(countryIso), nationalNumber)) {
            is DialPhoneTargetResult.Ready -> null
            is DialPhoneTargetResult.Invalid -> if (countryIso.equals("CN", true)) {
                ChinaMobileValidationMessage
            } else {
                InvalidPhoneNumberMessage
            }
        }
    }

    fun systemDialTarget(
        countryIso: String,
        countryDialCode: String,
        nationalNumber: String
    ): String {
        if (nationalNumber.none(Char::isDigit)) return ""
        return when (val result = resolve(countryIso, countryDialCode, nationalNumber)) {
            is DialPhoneTargetResult.Ready -> result.target.systemDialNumber
            is DialPhoneTargetResult.Invalid -> ""
        }
    }

    fun isValidChinaMobileE164(number: String): Boolean {
        if (!number.startsWith("+86")) return false
        return ChinaMobilePattern.matches(number.removePrefix("+86"))
    }

    fun resolve(
        countryIso: String,
        countryDialCode: String,
        rawNumber: String
    ): DialPhoneTargetResult {
        val parsed = splitExtension(rawNumber)
        if (parsed.main.none(Char::isDigit)) {
            return DialPhoneTargetResult.Invalid(InvalidPhoneNumberMessage)
        }
        val compactMain = parsed.main.trim().filter { it.isDigit() || it == '+' }
        val explicitDigits = compactMain.filter(Char::isDigit)
        val explicitForeignNumber =
            compactMain.startsWith("+") && !compactMain.startsWith("+86") ||
                explicitDigits.startsWith("00") && !explicitDigits.startsWith("0086")
        if (explicitForeignNumber) {
            return resolveInternational(
                mainNumber = parsed.main,
                displayNumber = rawNumber.trim(),
                extension = parsed.extension,
                countryDialCode = ""
            )
        }
        return if (countryIso.equals("CN", ignoreCase = true) ||
            countryDialCode.filter(Char::isDigit) == "86"
        ) {
            resolveChina(parsed.main, rawNumber.trim(), parsed.extension)
        } else {
            resolveInternational(
                mainNumber = parsed.main,
                displayNumber = rawNumber.trim(),
                extension = parsed.extension,
                countryDialCode = countryDialCode
            )
        }
    }

    private fun resolveChina(
        mainNumber: String,
        displayNumber: String,
        extension: String
    ): DialPhoneTargetResult {
        val compact = mainNumber.trim().filter { it.isDigit() || it == '+' }
        val rawDigits = compact.filter(Char::isDigit)
        val explicitChina = compact.startsWith("+86") || rawDigits.startsWith("0086")
        val national = when {
            compact.startsWith("+86") -> rawDigits.drop(2)
            rawDigits.startsWith("0086") -> rawDigits.drop(4)
            rawDigits.startsWith("86") && rawDigits.length >= 12 -> rawDigits.drop(2)
            else -> rawDigits
        }
        val direct = chinaTarget(national, displayNumber, extension)
        if (direct != null) return DialPhoneTargetResult.Ready(direct)
        if (explicitChina) {
            chinaTarget("0$national", displayNumber, extension)?.let {
                return DialPhoneTargetResult.Ready(it)
            }
        }
        return DialPhoneTargetResult.Invalid(InvalidPhoneNumberMessage)
    }

    private fun chinaTarget(
        national: String,
        displayNumber: String,
        extension: String
    ): DialPhoneTarget? {
        val type = when {
            national in ChinaEmergencyNumbers -> DialPhoneNumberType.CHINA_EMERGENCY
            ChinaMobilePattern.matches(national) -> DialPhoneNumberType.CHINA_MOBILE
            ChinaFixedLinePattern.matches(national) -> DialPhoneNumberType.CHINA_FIXED_LINE
            ChinaServicePattern.matches(national) -> DialPhoneNumberType.CHINA_SERVICE
            ChinaLocalOrShortPattern.matches(national) ->
                DialPhoneNumberType.CHINA_LOCAL_OR_SHORT
            else -> return null
        }
        val canonical = when (type) {
            DialPhoneNumberType.CHINA_MOBILE -> "+86$national"
            DialPhoneNumberType.CHINA_FIXED_LINE -> "+86${national.drop(1)}"
            else -> national
        }
        val systemNumber = when (type) {
            DialPhoneNumberType.CHINA_MOBILE,
            DialPhoneNumberType.CHINA_FIXED_LINE -> canonical
            else -> national
        }
        return DialPhoneTarget(
            displayNumber = displayNumber,
            canonicalNumber = canonical,
            networkDialNumber = national,
            systemDialNumber = systemNumber,
            type = type,
            postConnectDtmf = extension
        )
    }

    private fun resolveInternational(
        mainNumber: String,
        displayNumber: String,
        extension: String,
        countryDialCode: String
    ): DialPhoneTargetResult {
        val compact = mainNumber.trim().filter { it.isDigit() || it == '+' }
        val countryDigits = countryDialCode.filter(Char::isDigit)
        val canonical = when {
            compact.startsWith("+") -> compact
            compact.startsWith("00") -> "+${compact.drop(2)}"
            countryDigits.isNotBlank() -> "+$countryDigits${compact.filter(Char::isDigit).trimStart('0')}"
            else -> ""
        }
        val digits = canonical.drop(1)
        if (!canonical.startsWith("+") ||
            digits.length !in 7..15 ||
            digits.any { !it.isDigit() } ||
            digits.startsWith("0")
        ) {
            return DialPhoneTargetResult.Invalid(InvalidPhoneNumberMessage)
        }
        return DialPhoneTargetResult.Ready(
            DialPhoneTarget(
                displayNumber = displayNumber,
                canonicalNumber = canonical,
                networkDialNumber = "00$digits",
                systemDialNumber = canonical,
                type = DialPhoneNumberType.INTERNATIONAL,
                postConnectDtmf = extension
            )
        )
    }

    private fun splitExtension(rawNumber: String): ParsedPhoneInput {
        val trimmed = rawNumber.trim().removePrefix("tel:")
        ExplicitExtensionPattern.find(trimmed)?.let { match ->
            return ParsedPhoneInput(
                main = trimmed.substring(0, match.range.first),
                extension = match.groupValues[1]
            )
        }
        TrailingDashExtensionPattern.find(trimmed)?.let { match ->
            val base = trimmed.substring(0, match.range.first)
            val allDigits = trimmed.filter(Char::isDigit)
            val baseDigits = base.filter(Char::isDigit)
            if (allDigits.length > 12 && baseDigits.length in 3..12) {
                return ParsedPhoneInput(base, match.groupValues[1])
            }
        }
        return ParsedPhoneInput(trimmed, "")
    }

    private fun countryDialCode(countryIso: String): String = when (countryIso.uppercase()) {
        "CN" -> "+86"
        "US" -> "+1"
        "JP" -> "+81"
        "SG" -> "+65"
        else -> ""
    }

    private data class ParsedPhoneInput(
        val main: String,
        val extension: String
    )
}
