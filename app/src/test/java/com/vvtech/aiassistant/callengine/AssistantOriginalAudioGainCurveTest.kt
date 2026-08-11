package com.vvtech.aiassistant.callengine

import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantOriginalAudioGainCurveTest {
    @Test
    fun `gain curve keeps boundaries unchanged`() {
        assertEquals(0f, AssistantOriginalAudioGainCurve.gain(0), 0f)
        assertEquals(1f, AssistantOriginalAudioGainCurve.gain(100), 0f)
    }

    @Test
    fun `configured percentages map to linear pcm gain`() {
        assertEquals(0.1f, AssistantOriginalAudioGainCurve.gain(10), 0.0001f)
        assertEquals(0.2f, AssistantOriginalAudioGainCurve.gain(20), 0.0001f)
        assertEquals(0.5f, AssistantOriginalAudioGainCurve.gain(50), 0.0001f)
    }

    @Test
    fun `gain curve clamps out of range values`() {
        assertEquals(0f, AssistantOriginalAudioGainCurve.gain(-10), 0f)
        assertEquals(1f, AssistantOriginalAudioGainCurve.gain(120), 0f)
    }
}
