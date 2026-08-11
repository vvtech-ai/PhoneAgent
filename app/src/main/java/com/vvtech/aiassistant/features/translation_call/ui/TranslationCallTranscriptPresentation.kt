package com.vvtech.aiassistant.features.translation_call.ui

import com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem

internal data class TranslationTranscriptLines(
    val primary: String,
    val secondary: String?
)

internal fun translationTranscriptLatestScrollKey(
    transcripts: List<TranslationCallTranscriptItem>
): String = transcripts.lastOrNull()?.let { latest ->
    listOf(
        latest.segmentId,
        latest.sourceText,
        latest.translatedText,
        latest.final.toString()
    ).joinToString(separator = "\u0000")
}.orEmpty()

internal fun translationTranscriptLines(
    item: TranslationCallTranscriptItem
): TranslationTranscriptLines {
    val source = item.sourceText.trim()
    val translated = item.translatedText.trim()
    val localSpeaker = item.sourceLeg.equals("user", ignoreCase = true) ||
        item.sourceLeg.equals("local", ignoreCase = true)
    val preferred = if (localSpeaker) source else translated
    val alternate = if (localSpeaker) translated else source
    return TranslationTranscriptLines(
        primary = preferred.ifBlank { alternate },
        secondary = alternate.takeIf {
            preferred.isNotBlank() && it.isNotBlank() && it != preferred
        }
    )
}
