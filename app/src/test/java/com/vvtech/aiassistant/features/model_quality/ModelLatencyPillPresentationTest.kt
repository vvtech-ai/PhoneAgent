package com.vvtech.aiassistant.features.model_quality

import com.vvtech.aiassistant.domain.modelquality.ModelLatencyPolicy
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyReading
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class ModelLatencyPillPresentationTest {

    @Test
    fun `available states show actual milliseconds with exact colors`() {
        assertPresentation(ModelLatencyPolicy.fromProbe(true, 199), 0xFF34C759.toInt(), "199ms")
        assertPresentation(ModelLatencyPolicy.fromProbe(true, 200), 0xFFFFCC00.toInt(), "200ms")
        assertPresentation(ModelLatencyPolicy.fromProbe(true, 500), 0xFFFF9500.toInt(), "500ms")
    }

    @Test
    fun `unavailable is red and never exposes failed latency`() {
        assertPresentation(
            ModelLatencyPolicy.fromProbe(available = false, latencyMs = 46),
            0xFFFF3B30.toInt(),
            "不可用"
        )
    }

    @Test
    fun `unknown is gray without text`() {
        assertPresentation(
            ModelLatencyReading(ModelLatencyStatus.UNKNOWN),
            0xFFD1D5DB.toInt(),
            ""
        )
    }

    @Test
    fun `available state without latency falls back to unavailable`() {
        assertPresentation(
            ModelLatencyReading(ModelLatencyStatus.GOOD),
            0xFFFF3B30.toInt(),
            "不可用"
        )
    }

    private fun assertPresentation(
        reading: ModelLatencyReading,
        expectedBackgroundArgb: Int,
        expectedText: String
    ) {
        val presentation = modelLatencyPillPresentation(reading)
        assertEquals(expectedBackgroundArgb, presentation.backgroundArgb)
        assertEquals(expectedText, presentation.text)
    }
}
