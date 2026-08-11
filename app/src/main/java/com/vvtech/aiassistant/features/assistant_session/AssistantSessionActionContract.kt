package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.SummaryData

internal data class AssistantSessionActionableSummary(
    val summary: SummaryData,
    val confirmLabel: String,
    val primaryAction: AssistantActionChip?,
    val callPageSeed: CallPageData
)

internal data class AssistantSessionPendingSelectionContinuation(
    val sceneType: String,
    val targetName: String
)
