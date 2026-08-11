package com.vvtech.aiassistant.features.assistant_call_evaluation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
internal fun AgentCallEvaluationRoute(callId: String?) {
    val stableCallId = callId?.trim()?.takeIf(String::isNotEmpty) ?: return
    AgentCallEvaluationRoute(
        target = AgentCallEvaluationTarget.Call(stableCallId),
        viewModelKey = "call-evaluation:$stableCallId",
    )
}

@Composable
internal fun AgentBatchCallEvaluationRoute(batchId: String?) {
    val stableBatchId = batchId?.trim()?.takeIf(String::isNotEmpty) ?: return
    AgentCallEvaluationRoute(
        target = AgentCallEvaluationTarget.Batch(stableBatchId),
        viewModelKey = "batch-call-evaluation:$stableBatchId",
    )
}

@Composable
private fun AgentCallEvaluationRoute(
    target: AgentCallEvaluationTarget,
    viewModelKey: String,
) {
    val factory = remember(target) {
        AgentCallEvaluationViewModelFactory(target)
    }
    val evaluationViewModel: AgentCallEvaluationViewModel = viewModel(
        key = viewModelKey,
        factory = factory,
    )
    val state by evaluationViewModel.state.collectAsStateWithLifecycle()
    if (state.visible) {
        AgentCallEvaluationCard(
            state = state,
            onRatingSelected = evaluationViewModel::rate,
        )
    }
}
