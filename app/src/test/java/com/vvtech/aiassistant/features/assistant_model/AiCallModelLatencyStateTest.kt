package com.vvtech.aiassistant.features.assistant_model

import com.vvtech.aiassistant.domain.modelquality.ModelLatencyReading
import com.vvtech.aiassistant.domain.modelquality.ModelLatencyStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AiCallModelLatencyStateTest {

    @Test
    fun `models without a local record start gray`() {
        val state = AiCallModelLatencyState()

        assertEquals(
            ModelLatencyStatus.UNKNOWN,
            state.statusOf("QWEN_OMNI_PLUS")
        )
    }

    @Test
    fun `refresh without an effective result marks every requested model failed`() {
        val started = AiCallModelLatencyState(
            readings = mapOf(
                "QWEN_OMNI_PLUS" to ModelLatencyReading(
                    status = ModelLatencyStatus.GOOD,
                    latencyMs = 128
                )
            )
        ).startRefresh()
        val completed = started.completeRefresh(
            requestedModelIds = listOf("QWEN_OMNI_PLUS", "DOUBAO"),
            effectiveResults = emptyMap()
        )

        assertTrue(started.refreshing)
        assertFalse(completed.refreshing)
        assertEquals(ModelLatencyStatus.UNAVAILABLE, completed.statusOf("QWEN_OMNI_PLUS"))
        assertEquals(ModelLatencyStatus.UNAVAILABLE, completed.statusOf("DOUBAO"))
    }

    @Test
    fun `refresh retains only effective statuses returned by the source`() {
        val completed = AiCallModelLatencyState().startRefresh().completeRefresh(
            requestedModelIds = listOf("QWEN_OMNI_PLUS", "DOUBAO"),
            effectiveResults = mapOf(
                "QWEN_OMNI_PLUS" to ModelLatencyReading(
                    status = ModelLatencyStatus.FAIR,
                    latencyMs = 320
                )
            )
        )

        assertEquals(ModelLatencyStatus.FAIR, completed.statusOf("QWEN_OMNI_PLUS"))
        assertEquals(320L, completed.readingOf("QWEN_OMNI_PLUS").latencyMs)
        assertEquals(ModelLatencyStatus.UNAVAILABLE, completed.statusOf("DOUBAO"))
    }

    @Test
    fun `refresh accepts legacy Qwen latency result for the renamed model`() {
        val completed = AiCallModelLatencyState().startRefresh().completeRefresh(
            requestedModelIds = listOf("QWEN_OMNI_PLUS"),
            effectiveResults = mapOf(
                "QWEN_OMNI_FLASH" to ModelLatencyReading(
                    status = ModelLatencyStatus.GOOD,
                    latencyMs = 86
                )
            )
        )

        assertEquals(ModelLatencyStatus.GOOD, completed.statusOf("QWEN_OMNI_PLUS"))
        assertEquals(86L, completed.readingOf("QWEN_OMNI_PLUS").latencyMs)
    }

    @Test
    fun `failed backend result never exposes its elapsed time`() {
        val reading = aiCallModelLatencyReading(
            available = false,
            latencyMs = 46
        )

        assertEquals(ModelLatencyStatus.UNAVAILABLE, reading.status)
        assertNull(reading.latencyMs)
    }
}
