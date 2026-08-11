package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_tasks.AssistantFinalResultPage

@Composable
internal fun FinalResultPageV3(
    restaurantName: String,
    sceneType: String,
    summary: SummaryData?,
    callData: CallPageData,
    historyRecord: HistoryRecord?,
    onBackHome: () -> Unit,
    onShare: () -> Unit,
    aiModelEnabled: Boolean = false,
    aiModelInFlight: Boolean = false,
    onAiModelCallContact: () -> Unit = {}
) {
    AssistantFinalResultPage(
        state = buildFinalResultPageState(
            restaurantName = restaurantName,
            sceneType = sceneType,
            summary = summary,
            callData = callData,
            historyRecord = historyRecord
        ),
        onBackHome = onBackHome,
        onShare = onShare,
        aiModelEnabled = aiModelEnabled,
        aiModelInFlight = aiModelInFlight,
        onAiModelCallContact = onAiModelCallContact
    )
}

internal enum class FinalResultAnswer {
    Yes,
    No,
    Unknown
}
