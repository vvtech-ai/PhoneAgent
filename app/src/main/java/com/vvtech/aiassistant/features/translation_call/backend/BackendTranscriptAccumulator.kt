package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem

internal class BackendTranscriptAccumulator {
    private data class MutableSegment(
        val segmentId: String,
        val sourceLeg: String,
        var sourceText: String = "",
        var translatedText: String = "",
        var final: Boolean = false
    )

    private val segments = linkedMapOf<String, MutableSegment>()

    fun apply(
        event: BackendRealtimeEvent.TranscriptDelta,
        userLanguage: String,
        merchantLanguage: String
    ): TranslationCallTranscriptItem {
        val segment = segments.getOrPut(event.segmentId) {
            MutableSegment(event.segmentId, event.sourceLeg)
        }
        val next = if (event.replace) {
            event.text
        } else {
            when (event.kind) {
                "input" -> segment.sourceText + event.text
                else -> segment.translatedText + event.text
            }
        }
        if (event.kind == "input") {
            segment.sourceText = next
        } else {
            segment.translatedText = next
        }
        segment.final = segment.final || event.final
        val sourceIsUser = segment.sourceLeg == "user"
        return TranslationCallTranscriptItem(
            segmentId = segment.segmentId,
            sourceLeg = segment.sourceLeg,
            sourceLanguage = if (sourceIsUser) userLanguage else merchantLanguage,
            sourceText = segment.sourceText,
            translatedLanguage = if (sourceIsUser) merchantLanguage else userLanguage,
            translatedText = segment.translatedText,
            final = segment.final
        )
    }

    fun connectPrompt(
        event: BackendRealtimeEvent.ConnectPrompt,
        userLanguage: String,
        merchantLanguage: String
    ): TranslationCallTranscriptItem {
        val segment = MutableSegment(
            segmentId = event.segmentId,
            sourceLeg = "system",
            sourceText = event.sourceText,
            translatedText = event.translatedText,
            final = true
        )
        segments[event.segmentId] = segment
        return TranslationCallTranscriptItem(
            segmentId = segment.segmentId,
            sourceLeg = segment.sourceLeg,
            sourceLanguage = userLanguage,
            sourceText = segment.sourceText,
            translatedLanguage = merchantLanguage,
            translatedText = segment.translatedText,
            final = true
        )
    }

    fun clear() {
        segments.clear()
    }
}
