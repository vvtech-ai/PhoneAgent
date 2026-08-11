package com.vvtech.aiassistant.features.assistant_call_evaluation

import com.vvtech.aiassistant.data.repository.evaluation.AgentCallEvaluation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentCallEvaluationContractTest {
    @Test
    fun `evaluation is visible only when the historical model is available`() {
        val visible = evaluation(modelName = "Seeduplex").toUiState()
        val hidden = evaluation(modelName = "").toUiState()

        assertTrue(visible.visible)
        assertFalse(hidden.visible)
    }

    @Test
    fun `stored ratings map to card selections`() {
        assertEquals(AgentCallRating.Good, evaluation(rating = "GOOD").toUiState().rating)
        assertEquals(AgentCallRating.Bad, evaluation(rating = "BAD").toUiState().rating)
        assertEquals(null, evaluation(rating = null).toUiState().rating)
    }

    @Test
    fun `batch latency shows minimum and maximum using required range separator`() {
        assertEquals(
            "100ms～800ms",
            evaluation(minimumLatencyMs = 800L, maximumLatencyMs = 100L).toUiState().latencyText,
        )
    }

    @Test
    fun `single valid latency stays a single value`() {
        assertEquals(
            "320ms",
            evaluation(minimumLatencyMs = 320L, maximumLatencyMs = 320L).toUiState().latencyText,
        )
    }

    @Test
    fun `missing or invalid latency uses placeholder`() {
        assertEquals("--", evaluation(minimumLatencyMs = null, maximumLatencyMs = null).toUiState().latencyText)
        assertEquals("--", evaluation(minimumLatencyMs = -1L, maximumLatencyMs = null).toUiState().latencyText)
    }

    private fun evaluation(
        modelName: String = "QwenOmniPlus",
        rating: String? = null,
        minimumLatencyMs: Long? = 320L,
        maximumLatencyMs: Long? = 320L,
    ) = AgentCallEvaluation(
        callId = "call-1",
        modelName = modelName,
        minimumLatencyMs = minimumLatencyMs,
        maximumLatencyMs = maximumLatencyMs,
        rating = rating,
    )
}
