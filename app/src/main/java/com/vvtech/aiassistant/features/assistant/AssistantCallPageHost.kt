package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable

@Composable
internal fun AssistantCallPageHost(args: AssistantCallPageHostArgs) {
    when (args.currentPage) {
        FinalPage.Calls -> with(args.callList) {
            FinalCallsPageV3(
                records = records,
                onOpenRecord = onOpenRecord
            )
        }

        FinalPage.AgentCallDetail -> with(args.callDetail) {
            AgentCallDetailPage(
                record = record,
                onBack = onBack,
                onDial = onDial,
                onReturnTask = onReturnTask
            )
        }

        FinalPage.AiCall -> with(args.aiCall) {
            FinalAiCallPageV3(
                targetName = selectedRestaurantTitle ?: assistantUiState.callPageData.name,
                phoneNumber = assistantUiState.agentCallSpec?.phoneNumber.orEmpty(),
                seconds = seconds,
                callData = assistantUiState.callPageData,
                callUiMode = assistantUiState.callUiMode,
                handoffInFlight = assistantUiState.handoffInFlight,
                callMonitorState = assistantUiState.callMonitorState,
                callMonitorAudioRouteState = assistantUiState.callMonitorAudioRouteState,
                onHangup = onHangup,
                onMonitorToggle = onMonitorToggle,
                onAudioRouteSelect = onAudioRouteSelect
            )
        }

        FinalPage.Result -> with(args.result) {
            FinalResultPageV3(
                restaurantName = selectedRestaurantTitle
                    ?: assistantUiState.callPageData.name.ifBlank { "目标对象" },
                sceneType = assistantUiState.sceneType,
                summary = assistantUiState.summary,
                callData = assistantUiState.callPageData,
                historyRecord = assistantUiState.historyRecords.firstOrNull(),
                onBackHome = onBackHome,
                onShare = onShare,
                aiModelEnabled = resultCallId.isNotBlank(),
                aiModelInFlight = aiModelInFlight,
                onAiModelCallContact = onAiModelCallContact
            )
        }

        FinalPage.NormalCall -> with(args.normalCall) {
            FinalNormalCallPageV3(
                phoneNumber = phoneNumber,
                seconds = seconds,
                muted = muted,
                speakerEnabled = speakerEnabled,
                onBack = onBack,
                onMuteToggle = onMuteToggle,
                onSpeakerToggle = onSpeakerToggle,
                onHangup = onHangup
            )
        }

        FinalPage.TranslateCall -> with(args.translateCall) {
            FinalTranslateCallPageV3Safe(
                phoneNumber = phoneNumber,
                seconds = seconds,
                status = status,
                error = error,
                audioChannelStatus = audioChannelStatus,
                muted = muted,
                speakerEnabled = speakerEnabled,
                panelCollapsed = panelCollapsed,
                onMuteToggle = onMuteToggle,
                onSpeakerToggle = onSpeakerToggle,
                onPanelToggle = onPanelToggle,
                onHangup = onHangup
            )
        }

        else -> Unit
    }
}
