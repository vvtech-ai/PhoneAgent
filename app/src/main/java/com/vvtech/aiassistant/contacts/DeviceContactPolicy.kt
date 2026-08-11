package com.vvtech.aiassistant.contacts

internal object DeviceContactPolicy {
    private val mobilePattern = Regex("""1[3-9]\d{9}""")
    private val fixedLinePattern = Regex("""0\d{2,3}\d{7,8}""")
    private val localFixedLinePattern = Regex("""\d{7,8}""")
    private val servicePattern = Regex("""(?:400\d{7}|800\d{7}|95\d{3,8}|96\d{3,8}|1\d{4})""")
    private val extensionSeparatorPattern = Regex("""(?i)(?:转|ext\.?|x|#)""")
    private val extensionValuePattern = Regex("""(?i)(?:转|ext\.?|x|#)\s*(\d{1,6})""")
    private val callKeywords = listOf("打电话", "拨电话", "拨打", "联系", "通知", "叫", "让", "喊", "约", "打给", "拨给", "给")
    private val multiContactPattern = Regex(
        """(?:帮我)?(?:联系|通知|叫|让|喊|约|打给|拨给|给)([\u4e00-\u9fa5A-Za-z、和跟与及,，\s]{1,40}?)(?=打电话|拨电话|拨个电话|来个电话|过来|来|去|到|参加|开会|吃饭|面试|$|，|,|。)"""
    )
    private val contactNameSeparatorPattern = Regex("""(?:和|跟|与|及|、|,|，|\s+)""")
    private val contactPatterns = listOf(
        Regex("""(?:帮我)?给([\u4e00-\u9fa5A-Za-z]{1,12}?)(?=打电话|拨电话|拨个电话|来个电话)"""),
        Regex("""(?:联系|通知|叫|让|喊|约|打给|拨给)([\u4e00-\u9fa5A-Za-z]{1,12}?)(?=打电话|拨电话|来个电话|$|，|,|。)""")
    )

    fun normalizePhone(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.isBlank()) {
            return ""
        }

        val extension = extensionValuePattern.find(trimmed)?.groupValues?.getOrNull(1).orEmpty()
        val basePart = extensionSeparatorPattern.split(trimmed, limit = 2).firstOrNull().orEmpty()
        val baseDigits = basePart.filter(Char::isDigit)
        if (baseDigits.isBlank()) {
            return ""
        }

        val strippedMobile = stripMainlandPrefix(baseDigits)
        if (mobilePattern.matches(strippedMobile)) {
            return strippedMobile
        }

        val normalizedBase = when {
            fixedLinePattern.matches(baseDigits) -> baseDigits
            localFixedLinePattern.matches(baseDigits) -> baseDigits
            servicePattern.matches(baseDigits) -> baseDigits
            baseDigits.length in 5..20 -> baseDigits
            else -> ""
        }

        if (normalizedBase.isBlank()) {
            return ""
        }
        return if (extension.isBlank()) normalizedBase else "$normalizedBase-$extension"
    }

    fun extractCallContactCandidate(message: String): CallContactCandidate? {
        return extractCallContactCandidateNames(message)
            .firstOrNull()
            ?.let { CallContactCandidate(contactName = it) }
    }

    fun extractCallContactCandidateNames(message: String): List<String> {
        val normalized = message.trim()
        if (normalized.isBlank() || containsPhone(normalized) || !looksLikeCall(normalized)) {
            return emptyList()
        }
        val names = linkedSetOf<String>()
        multiContactPattern.findAll(normalized).forEach { match ->
            val segment = match.groupValues.getOrNull(1).orEmpty()
            splitContactNameSegment(segment).forEach(names::add)
        }
        contactPatterns.forEach { pattern ->
            pattern.find(normalized)?.groupValues?.getOrNull(1)?.trim()?.let { name ->
                splitContactNameSegment(name).forEach(names::add)
            }
        }
        return names.toList()
    }

    fun extractExplicitContact(message: String): ExplicitContactInfo? {
        val normalized = message.trim()
        if (normalized.isBlank()) return null
        val phoneMatch = mobilePattern.find(normalized) ?: return null
        val phone = phoneMatch.value
        val beforePhone = normalized.substring(0, phoneMatch.range.first)
        val cleaned = beforePhone
            .replace(Regex("""[的]?(?:电话号码|电话|手机号|手机|号码|联系方式)[是为]?[：:,，。.、\s]*$"""), "")
            .replace(Regex("""[,，。.、：:\s]+$"""), "")
            .trim()
        val name = cleaned
            .replace(Regex("""^(?:联系人|姓名|名字|收件人|收货人|我叫|我是)[是为]?[：:,，。.、\s]*"""), "")
            .trim()
        if (name.isBlank() || name.length > 12) return null
        if (!name.matches(Regex("""[一-龥A-Za-z]+"""))) return null
        return ExplicitContactInfo(contactName = name, phoneNumber = phone)
    }

    fun containsPhone(message: String): Boolean = mobilePattern.containsMatchIn(message)

    private fun looksLikeCall(message: String): Boolean = callKeywords.any(message::contains)

    private fun splitContactNameSegment(segment: String): List<String> {
        return contactNameSeparatorPattern.split(segment.trim())
            .map { it.trim() }
            .filter(::isPlausibleContactName)
    }

    private fun isPlausibleContactName(value: String): Boolean {
        if (value.isBlank() || value.length > 12) return false
        return value.matches(Regex("""[\u4e00-\u9fa5A-Za-z]+"""))
    }

    private fun stripMainlandPrefix(digits: String): String {
        return when {
            digits.startsWith("0086") && digits.length > 11 -> digits.removePrefix("0086")
            digits.startsWith("86") && digits.length > 11 -> digits.removePrefix("86")
            else -> digits
        }
    }
}
