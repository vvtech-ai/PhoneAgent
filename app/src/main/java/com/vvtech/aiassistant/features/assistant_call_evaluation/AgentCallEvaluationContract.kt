package com.vvtech.aiassistant.features.assistant_call_evaluation

import com.vvtech.aiassistant.data.repository.evaluation.AgentCallEvaluation

internal enum class AgentCallRating(val wireValue: String) {
    Good("GOOD"),
    Bad("BAD"),
}

internal data class AgentCallEvaluationUiState(
    val visible: Boolean = false,
    val modelName: String = "",
    val latencyText: String = "--",
    val rating: AgentCallRating? = null,
    val saving: Boolean = false,
    val message: String? = null,
)

internal fun AgentCallEvaluation.toUiState() = AgentCallEvaluationUiState(
    visible = modelName.isNotBlank(),
    modelName = modelName,
    latencyText = agentCallLatencyRangeText(minimumLatencyMs, maximumLatencyMs),
    rating = when (rating) {
        AgentCallRating.Good.wireValue -> AgentCallRating.Good
        AgentCallRating.Bad.wireValue -> AgentCallRating.Bad
        else -> null
    },
)

internal fun agentCallLatencyRangeText(minimumLatencyMs: Long?, maximumLatencyMs: Long?): String {
    val values = listOfNotNull(minimumLatencyMs, maximumLatencyMs).filter { it >= 0 }
    if (values.isEmpty()) return "--"
    val minimum = values.minOrNull() ?: return "--"
    val maximum = values.maxOrNull() ?: return "--"
    return if (minimum == maximum) "${minimum}ms" else "${minimum}ms～${maximum}ms"
}
