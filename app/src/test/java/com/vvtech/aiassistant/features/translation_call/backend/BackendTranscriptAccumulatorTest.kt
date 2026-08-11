package com.vvtech.aiassistant.features.translation_call.backend

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackendTranscriptAccumulatorTest {
    @Test
    fun `merges input and output deltas by segment`() {
        val accumulator = BackendTranscriptAccumulator()

        accumulator.apply(delta("input", "你", replace = false), "zh", "en")
        accumulator.apply(delta("input", "好", replace = false), "zh", "en")
        accumulator.apply(delta("output", "hello", replace = true), "zh", "en")
        val result = accumulator.apply(
            delta("output", "!", replace = false, final = true),
            "zh",
            "en"
        )

        assertEquals("你好", result.sourceText)
        assertEquals("hello!", result.translatedText)
        assertTrue(result.final)
    }

    @Test
    fun `keeps user and merchant language directions separate`() {
        val accumulator = BackendTranscriptAccumulator()

        val merchant = accumulator.apply(
            delta("input", "hello", sourceLeg = "merchant"),
            "zh",
            "en"
        )

        assertEquals("en", merchant.sourceLanguage)
        assertEquals("zh", merchant.translatedLanguage)
    }

    private fun delta(
        kind: String,
        text: String,
        sourceLeg: String = "user",
        replace: Boolean = true,
        final: Boolean = false
    ) = BackendRealtimeEvent.TranscriptDelta(
        segmentId = "segment-1",
        sourceLeg = sourceLeg,
        targetLeg = if (sourceLeg == "user") "merchant" else "user",
        kind = kind,
        text = text,
        final = final,
        replace = replace
    )
}
