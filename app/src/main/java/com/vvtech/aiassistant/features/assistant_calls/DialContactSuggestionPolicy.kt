package com.vvtech.aiassistant.features.assistant_calls

internal data class DialContactEntry(
    val contactId: String? = null,
    val displayName: String,
    val phoneNumber: String,
    val pinyinTokens: List<String>
)

internal enum class DialContactMatchKind {
    NAME,
    NUMBER
}

internal data class DialContactSuggestion(
    val contactId: String?,
    val displayName: String,
    val phoneNumber: String,
    val matchKind: DialContactMatchKind,
    val numberHitStart: Int? = null,
    val numberHitEndExclusive: Int? = null
)

internal data class DialTargetSelection(
    val phoneNumber: String,
    val displayName: String = "",
    val callKind: DialRecentCallKind? = null,
    val countryIso: String = "",
    val callerLanguageCode: String = "",
    val calleeLanguageCode: String = ""
)

internal fun dialContactSuggestions(
    query: String,
    contacts: List<DialContactEntry>,
    limit: Int = MaxDialContactSuggestions
): List<DialContactSuggestion> {
    val normalizedQuery = query.trim()
    if (normalizedQuery.isEmpty() || normalizedQuery.any { !it.isDigit() }) return emptyList()

    val nameMatches = mutableListOf<DialContactSuggestion>()
    val numberMatches = mutableListOf<DialContactSuggestion>()
    contacts
        .groupBy(::dialContactIdentity)
        .values
        .forEach { phoneRows ->
            val first = phoneRows.firstOrNull() ?: return@forEach
            if (dialContactNameMatches(first.pinyinTokens, normalizedQuery)) {
                nameMatches += first.toSuggestion(DialContactMatchKind.NAME)
                return@forEach
            }
            phoneRows.forEach { entry ->
                val numberBody = dialSubscriberNumberForDisplay(entry.phoneNumber)
                    .filter(Char::isDigit)
                val hitStart = numberBody.indexOf(normalizedQuery)
                if (hitStart >= 0) {
                    numberMatches += entry.toSuggestion(
                        kind = DialContactMatchKind.NUMBER,
                        hitStart = hitStart,
                        hitEndExclusive = hitStart + normalizedQuery.length
                    )
                }
            }
        }

    return (nameMatches + numberMatches).take(limit.coerceAtLeast(0))
}

internal fun dialContactNameMatches(
    pinyinTokens: List<String>,
    digitQuery: String
): Boolean {
    if (digitQuery.isEmpty() || digitQuery.any { !it.isDigit() }) return false
    val normalizedTokens = pinyinTokens.map { token ->
        token.uppercase().filter { it in 'A'..'Z' }
    }.filter(String::isNotBlank)
    if (normalizedTokens.isEmpty()) return false

    val initials = normalizedTokens.mapNotNull(String::firstOrNull).joinToString("")
    val fullPinyin = normalizedTokens.joinToString("")
    return lettersToT9(initials).startsWith(digitQuery) ||
        lettersToT9(fullPinyin).startsWith(digitQuery)
}

internal fun formattedDigitHighlightRange(
    formattedNumber: String,
    rawDigitStart: Int?,
    rawDigitEndExclusive: Int?
): IntRange? {
    val start = rawDigitStart ?: return null
    val endExclusive = rawDigitEndExclusive ?: return null
    if (start < 0 || endExclusive <= start) return null

    var digitIndex = -formattedCountryPrefixDigitCount(formattedNumber)
    var formattedStart = -1
    var formattedEnd = -1
    formattedNumber.forEachIndexed { index, char ->
        if (!char.isDigit()) return@forEachIndexed
        if (digitIndex == start) formattedStart = index
        digitIndex += 1
        if (digitIndex == endExclusive) {
            formattedEnd = index
            return@forEachIndexed
        }
    }
    return if (formattedStart >= 0 && formattedEnd >= formattedStart) {
        formattedStart..formattedEnd
    } else {
        null
    }
}

private fun formattedCountryPrefixDigitCount(formattedNumber: String): Int = when {
    formattedNumber.startsWith("+86") -> 2
    formattedNumber.startsWith("+81") -> 2
    formattedNumber.startsWith("+65") -> 2
    formattedNumber.startsWith("+1") -> 1
    else -> 0
}

private fun dialContactIdentity(entry: DialContactEntry): String =
    entry.contactId?.let { "id:$it" } ?: "name:${entry.displayName}"

private fun DialContactEntry.toSuggestion(
    kind: DialContactMatchKind,
    hitStart: Int? = null,
    hitEndExclusive: Int? = null
) = DialContactSuggestion(
    contactId = contactId,
    displayName = displayName,
    phoneNumber = phoneNumber,
    matchKind = kind,
    numberHitStart = hitStart,
    numberHitEndExclusive = hitEndExclusive
)

private fun lettersToT9(value: String): String = value.mapNotNull { char ->
    when (char.uppercaseChar()) {
        in 'A'..'C' -> '2'
        in 'D'..'F' -> '3'
        in 'G'..'I' -> '4'
        in 'J'..'L' -> '5'
        in 'M'..'O' -> '6'
        in 'P'..'S' -> '7'
        in 'T'..'V' -> '8'
        in 'W'..'Z' -> '9'
        else -> null
    }
}.joinToString("")

private const val MaxDialContactSuggestions = 10
