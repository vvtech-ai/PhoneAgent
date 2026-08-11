package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.features.assistant.AssistantViewModel

internal fun AssistantViewModel.localizedTaskReadyStatus(): String =
    localizedStatusTextProvider.taskReadyStatus()

internal fun AssistantViewModel.localizedDetailLabel(): String =
    localizedStatusTextProvider.detailLabel()

internal fun AssistantViewModel.localizedContactLabel(): String =
    localizedStatusTextProvider.contactLabel()

internal fun AssistantViewModel.localizedListeningStatus(): String =
    localizedStatusTextProvider.listeningStatus()

internal fun AssistantViewModel.localizedStartingVoiceStatus(): String =
    localizedStatusTextProvider.startingVoiceStatus()

internal fun AssistantViewModel.localizedConnectingVoiceStatus(): String =
    localizedStatusTextProvider.connectingVoiceStatus()

internal fun AssistantViewModel.localizedReconnectingVoiceStatus(): String =
    localizedStatusTextProvider.reconnectingVoiceStatus()

internal fun AssistantViewModel.localizedTapMicToContinueStatus(): String =
    localizedStatusTextProvider.tapMicToContinueStatus()

internal fun AssistantViewModel.localizedPausedTapToContinueStatus(): String =
    localizedStatusTextProvider.pausedTapToContinueStatus()

internal fun AssistantViewModel.localizedNoValidSpeechStatus(): String =
    localizedStatusTextProvider.noValidSpeechStatus()

internal fun AssistantViewModel.localizedConfirmingDetailsStatus(
    sceneType: String? = internalUiState.value.sceneType
): String =
    localizedStatusTextProvider.confirmingDetailsStatus(sceneType)
