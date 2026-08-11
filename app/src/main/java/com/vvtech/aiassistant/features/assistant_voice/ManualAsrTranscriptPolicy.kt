package com.vvtech.aiassistant.features.assistant_voice

internal const val ManualAsrFinalizeMaxCaptureMillis = 2_000L

internal data class ManualAsrReleaseTranscript(
    val text: String,
    val fallbackAddsBufferedContent: Boolean
)

internal fun resolveManualAsrReleaseTranscript(
    bufferedFinal: String?,
    fallback: String?
): ManualAsrReleaseTranscript {
    val bufferedText = bufferedFinal?.trim().orEmpty()
    val fallbackText = fallback?.trim().orEmpty()
    val mergedText = mergeManualAsrTranscript(
        prefix = bufferedText.takeIf { it.isNotBlank() },
        next = fallbackText
    )
    return ManualAsrReleaseTranscript(
        text = mergedText,
        fallbackAddsBufferedContent = bufferedText.isNotBlank() && mergedText != bufferedText
    )
}

internal fun mergeManualAsrTranscript(prefix: String?, next: String): String {
    val left = prefix?.trim().orEmpty()
    val right = next.trim()
    if (left.isBlank()) return right
    if (right.isBlank()) return left
    if (right == left) return left
    if (right.startsWith(left)) return right
    if (left.endsWith(right)) return left
    val overlapLength = longestSuffixPrefixOverlap(left, right)
    if (overlapLength > 0) return left + right.drop(overlapLength)
    return "$left $right"
}

private fun longestSuffixPrefixOverlap(left: String, right: String): Int {
    val maxLength = minOf(left.length, right.length)
    for (length in maxLength downTo 1) {
        if (left.takeLast(length) == right.take(length)) return length
    }
    return 0
}
