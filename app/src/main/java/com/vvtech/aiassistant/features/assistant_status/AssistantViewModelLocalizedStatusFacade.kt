package com.vvtech.aiassistant.features.assistant

internal fun AssistantViewModel.localizedTaskReadyStatus(): String =
    localizedStatusTextProvider.taskReadyStatus()

internal fun AssistantViewModel.localizedDetailLabel(): String =
    localizedStatusTextProvider.detailLabel()

internal fun AssistantViewModel.localizedContactLabel(): String =
    localizedStatusTextProvider.contactLabel()

internal fun AssistantViewModel.localizedListeningStatus(): String =
    localizedStatusTextProvider.listeningStatus()

internal fun AssistantViewModel.localizedAiSpeakingStatus(): String =
    localizedStatusTextProvider.aiSpeakingStatus()

internal fun AssistantViewModel.localizedStartingVoiceStatus(): String =
    localizedStatusTextProvider.startingVoiceStatus()

internal fun AssistantViewModel.localizedConnectingVoiceStatus(): String =
    localizedStatusTextProvider.connectingVoiceStatus()

internal fun AssistantViewModel.localizedReconnectingVoiceStatus(): String =
    localizedStatusTextProvider.reconnectingVoiceStatus()

internal fun AssistantViewModel.localizedRealtimeTranscriptionConnectingStatus(): String =
    localizedStatusTextProvider.realtimeTranscriptionConnectingStatus()

internal fun AssistantViewModel.localizedSwitchingSceneStatus(): String =
    localizedStatusTextProvider.switchingSceneStatus()

internal fun AssistantViewModel.localizedSpeechFallbackSwitchingStatus(): String =
    localizedStatusTextProvider.speechFallbackSwitchingStatus()

internal fun AssistantViewModel.localizedRealtimeFallbackStatus(): String =
    localizedStatusTextProvider.realtimeFallbackStatus()

internal fun AssistantViewModel.localizedVoiceUnavailableStatus(): String =
    localizedStatusTextProvider.voiceUnavailableStatus()

internal fun AssistantViewModel.localizedVoiceInterruptedStatus(): String =
    localizedStatusTextProvider.voiceInterruptedStatus()

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

internal fun AssistantViewModel.localizedStatusHintOrFallback(statusHint: String?, fallback: String): String =
    localizedStatusTextProvider.statusHintOrFallback(statusHint, fallback)

internal fun AssistantViewModel.localizedConfirmingSelectionOptionStatus(title: String): String =
    localizedStatusTextProvider.confirmingSelectionOptionStatus(title)

internal fun AssistantViewModel.localizedSelectionOptionConfirmFailureError(): String =
    localizedStatusTextProvider.selectionOptionConfirmFailureError()

internal fun AssistantViewModel.localizedSelectionOptionConfirmFailureStatus(): String =
    localizedStatusTextProvider.selectionOptionConfirmFailureStatus()
