package com.vvtech.aiassistant.domain.modelquality

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ModelLatencyPolicyTest {

    @Test
    fun `valid latency uses shared boundaries`() {
        assertEquals(ModelLatencyStatus.GOOD, ModelLatencyPolicy.fromProbe(true, 199).status)
        assertEquals(ModelLatencyStatus.FAIR, ModelLatencyPolicy.fromProbe(true, 200).status)
        assertEquals(ModelLatencyStatus.FAIR, ModelLatencyPolicy.fromProbe(true, 499).status)
        assertEquals(ModelLatencyStatus.HIGH, ModelLatencyPolicy.fromProbe(true, 500).status)
    }

    @Test
    fun `unavailable wins over failed probe latency`() {
        val reading = ModelLatencyPolicy.fromProbe(
            available = false,
            latencyMs = 46
        )

        assertEquals(ModelLatencyStatus.UNAVAILABLE, reading.status)
        assertNull(reading.latencyMs)
    }

    @Test
    fun `available response without valid latency is unavailable`() {
        assertEquals(
            ModelLatencyStatus.UNAVAILABLE,
            ModelLatencyPolicy.fromProbe(available = true, latencyMs = null).status
        )
        assertEquals(
            ModelLatencyStatus.UNAVAILABLE,
            ModelLatencyPolicy.fromProbe(available = true, latencyMs = -1).status
        )
    }
}
