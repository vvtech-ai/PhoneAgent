package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantDoubaoTranscriptAccumulatorTest {
    @Test
    fun `source deltas keep one stable turn until translation ends`() {
        val accumulator = accumulator()

        val first = accumulator.applySource("a", AssistantDoubaoProto.SourceResponse)!!
        val second = accumulator.applySource("b", AssistantDoubaoProto.SourceResponse)!!
        val sourceEnd = accumulator.applySource("abc", AssistantDoubaoProto.SourceEnd)!!

        assertEquals(first.id, second.id)
        assertEquals(first.id, sourceEnd.id)
        assertEquals("ab", second.sourceText)
        assertEquals("abc", sourceEnd.sourceText)
        assertFalse(sourceEnd.final)
    }

    @Test
    fun `translation deltas are merged and next source starts new turn after final`() {
        val accumulator = accumulator()

        val source = accumulator.applySource("abc", AssistantDoubaoProto.SourceEnd)!!
        val translatedPart = accumulator.applyTranslation("he", AssistantDoubaoProto.TranslationResponse)!!
        val translatedNext = accumulator.applyTranslation("llo", AssistantDoubaoProto.TranslationResponse)!!
        val translatedFinal = accumulator.applyTranslation("hello", AssistantDoubaoProto.TranslationEnd)!!
        val nextSource = accumulator.applySource("x", AssistantDoubaoProto.SourceResponse)!!

        assertEquals(source.id, translatedPart.id)
        assertEquals(source.id, translatedNext.id)
        assertEquals(source.id, translatedFinal.id)
        assertEquals("hello", translatedNext.translatedText)
        assertEquals("hello", translatedFinal.translatedText)
        assertTrue(translatedFinal.final)
        assertNotEquals(source.id, nextSource.id)
    }

    @Test
    fun `comma ended doubao segments merge while each next segment arrives within five seconds`() {
        var nowMillis = 1_000L
        val accumulator = accumulator(clockMillis = { nowMillis })

        val firstSource = accumulator.applySource("第一段，", AssistantDoubaoProto.SourceEnd)!!
        val firstFinal = accumulator.applyTranslation("First,", AssistantDoubaoProto.TranslationEnd)!!
        nowMillis += 5_000L
        val secondSource = accumulator.applySource("第二段，", AssistantDoubaoProto.SourceStart)!!
        val secondFinal = accumulator.applyTranslation("second,", AssistantDoubaoProto.TranslationEnd)!!
        nowMillis += 5_000L
        val thirdSource = accumulator.applySource("第三段。", AssistantDoubaoProto.SourceStart)!!
        val thirdFinal = accumulator.applyTranslation("third.", AssistantDoubaoProto.TranslationEnd)!!

        assertEquals(firstSource.id, firstFinal.id)
        assertEquals(firstSource.id, secondSource.id)
        assertEquals(firstSource.id, secondFinal.id)
        assertEquals(firstSource.id, thirdSource.id)
        assertEquals(firstSource.id, thirdFinal.id)
        assertEquals("第一段，第二段，第三段。", thirdFinal.sourceText)
        assertEquals("First, second, third.", thirdFinal.translatedText)
    }

    @Test
    fun `comma ended doubao segment stays separate when next segment arrives after five seconds`() {
        var nowMillis = 1_000L
        val accumulator = accumulator(clockMillis = { nowMillis })

        val firstSource = accumulator.applySource("第一段，", AssistantDoubaoProto.SourceEnd)!!
        accumulator.applyTranslation("First,", AssistantDoubaoProto.TranslationEnd)!!
        nowMillis += 5_001L
        val secondSource = accumulator.applySource("第二段。", AssistantDoubaoProto.SourceStart)!!
        val secondFinal = accumulator.applyTranslation("Second.", AssistantDoubaoProto.TranslationEnd)!!

        assertNotEquals(firstSource.id, secondSource.id)
        assertEquals(secondSource.id, secondFinal.id)
        assertEquals("第二段。", secondFinal.sourceText)
        assertEquals("Second.", secondFinal.translatedText)
    }

    private fun accumulator(
        clockMillis: () -> Long = { 0L }
    ) = AssistantDoubaoTranscriptAccumulator(
        speaker = "local",
        sourceLanguage = "zh",
        targetLanguage = "en",
        log = {},
        clockMillis = clockMillis
    )
}
