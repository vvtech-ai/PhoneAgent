package com.vvtech.aiassistant.features.translation_call.ui

import com.vvtech.aiassistant.features.translation_call.state.TranslationCallTranscriptItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TranslationCallTranscriptPresentationTest {
    @Test
    fun localSpeakerShowsUserSourceLanguageAbovePeerTranslation() {
        val lines = translationTranscriptLines(
            item(sourceLeg = "local", source = "我方原文", translated = "Peer translation")
        )

        assertEquals("我方原文", lines.primary)
        assertEquals("Peer translation", lines.secondary)
    }

    @Test
    fun remoteSpeakerShowsUserTranslationAbovePeerSourceLanguage() {
        val lines = translationTranscriptLines(
            item(sourceLeg = "remote", source = "Peer source", translated = "我方译文")
        )

        assertEquals("我方译文", lines.primary)
        assertEquals("Peer source", lines.secondary)
    }

    @Test
    fun singleAvailableTextDoesNotCreateEmptySecondLine() {
        val sourceOnly = translationTranscriptLines(item("remote", "对方原文", ""))
        val translationOnly = translationTranscriptLines(item("remote", "", "我方译文"))

        assertEquals("对方原文", sourceOnly.primary)
        assertNull(sourceOnly.secondary)
        assertEquals("我方译文", translationOnly.primary)
        assertNull(translationOnly.secondary)
    }

    @Test
    fun latestScrollKeyChangesForNewSegmentAndIncrementalText() {
        val first = item("remote", "Hello", "你好")
        val incremental = first.copy(translatedText = "你好，世界")
        val next = first.copy(segmentId = "segment-2", sourceText = "Next")

        val firstKey = translationTranscriptLatestScrollKey(listOf(first))

        assertEquals("", translationTranscriptLatestScrollKey(emptyList()))
        assertEquals(false, firstKey == translationTranscriptLatestScrollKey(listOf(incremental)))
        assertEquals(false, firstKey == translationTranscriptLatestScrollKey(listOf(first, next)))
    }

    private fun item(
        sourceLeg: String,
        source: String,
        translated: String
    ) = TranslationCallTranscriptItem(
        segmentId = "segment-1",
        sourceLeg = sourceLeg,
        sourceLanguage = "zh",
        sourceText = source,
        translatedLanguage = "en",
        translatedText = translated,
        final = true
    )
}
