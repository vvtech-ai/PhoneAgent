package com.vvtech.aiassistant.features.assistant_session

private val PhoneThenPartyPattern =
    Regex("""(?<!\d)(1[3-9]\d{9})([1-9]\d?)(\s*(?:\u4e2a?\u4eba|\u4f4d))(?!\d)""")

internal fun normalizeReservationAsrTranscript(text: String): String {
    if (text.isBlank()) return text
    return PhoneThenPartyPattern.replace(text) { match ->
        val phone = match.groupValues[1]
        val party = match.groupValues[2]
        val unit = match.groupValues[3]
        "$phone\uFF0C$party$unit"
    }
}
