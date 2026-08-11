package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.ResultSummaryPayload

internal fun AssistantViewModel.isOutboundCallAudioSuppressed(): Boolean =
    outboundCallAudioGate.isSuppressed()

internal fun AssistantViewModel.outboundCallAudioGateSnapshot(): String =
    outboundCallAudioGate.snapshot()

internal fun AssistantViewModel.logOutboundCallAudioGate(
    reason: String,
    suppressed: Boolean = isOutboundCallAudioSuppressed()
) = outboundCallAudioGate.log(reason, suppressed)

internal fun AssistantViewModel.beginOutboundCallAudioSuppression(reason: String) =
    outboundCallAudioGate.beginSuppression(reason)

internal fun AssistantViewModel.endOutboundCallAudioSuppression(reason: String) =
    outboundCallAudioGate.endSuppression(reason)

fun AssistantViewModel.onMicClick() =
    voiceEntryActionHandler.onMicClick()

fun AssistantViewModel.onApiMicClick() =
    voiceEntryActionHandler.onApiMicClick()

fun AssistantViewModel.onManualAsrPress() =
    voiceEntryActionHandler.onManualAsrPress()

fun AssistantViewModel.onManualAsrRelease() =
    voiceEntryActionHandler.onManualAsrRelease()

fun AssistantViewModel.onManualAsrCancel() =
    voiceEntryActionHandler.onManualAsrCancel()

fun AssistantViewModel.onManualAsrTooShort() =
    voiceEntryActionHandler.onManualAsrTooShort()

fun AssistantViewModel.onTtsInterrupted() =
    voiceEntryActionHandler.onTtsInterrupted()

fun AssistantViewModel.stopTtsPlaybackForOptionSelection() =
    voiceEntryActionHandler.stopTtsPlaybackForOptionSelection()

fun AssistantViewModel.stopVoiceInteraction(reason: String = "stop_voice_interaction") =
    voiceRuntimeHandler.stopVoiceInteraction(reason)

internal fun AssistantViewModel.closeTaskVoiceRealtime(reason: String) =
    voiceRuntimeHandler.closeTaskVoiceRealtime(reason)

internal fun AssistantViewModel.startApiListening(trigger: String = "unspecified") =
    voiceRuntimeHandler.startApiListening(trigger)

internal fun AssistantViewModel.stopApiListening(preserveLateFinalGrace: Boolean = false) =
    voiceRuntimeHandler.stopApiListening(preserveLateFinalGrace)

internal fun AssistantViewModel.stopLiveTranscription(suppressRestart: Boolean = true) =
    voiceRuntimeHandler.stopLiveTranscription(suppressRestart)

internal fun AssistantViewModel.ensureRealtimeSession(silentResume: Boolean = false) =
    voiceRuntimeHandler.ensureRealtimeSession(silentResume)

internal fun AssistantViewModel.stopRealtimeSession() =
    voiceRuntimeHandler.stopRealtimeSession()

internal fun AssistantViewModel.resumeListeningAfterTts() =
    voiceRuntimeHandler.resumeListeningAfterTts()

internal fun AssistantViewModel.activeVoiceTaskId(): String? =
    voiceRuntimeHandler.activeVoiceTaskId()

internal fun AssistantViewModel.scheduleTextProcessingStatusProgress(text: String) =
    voiceRuntimeHandler.scheduleTextProcessingStatusProgress(text)

internal fun AssistantViewModel.cancelTextProcessingStatusProgress() =
    voiceRuntimeHandler.cancelTextProcessingStatusProgress()

internal fun AssistantViewModel.ensureSceneDialogContext(
    session: AssistantSessionResponse,
    carryoverUtterance: String?,
    syntheticAssistantPrompt: String?,
    forceRestart: Boolean
) = voiceRuntimeHandler.ensureSceneDialogContext(
    session = session,
    carryoverUtterance = carryoverUtterance,
    syntheticAssistantPrompt = syntheticAssistantPrompt,
    forceRestart = forceRestart
)

internal fun AssistantViewModel.enqueueRecognizedTurn(text: String) =
    voiceRuntimeHandler.enqueueRecognizedTurn(text)

fun AssistantViewModel.startVoiceInteraction() =
    voiceEntryActionHandler.startVoiceInteraction()

fun AssistantViewModel.startVoiceInteractionForNewTaskEntry() =
    voiceEntryActionHandler.startVoiceInteractionForNewTaskEntry()

fun AssistantViewModel.toggleVoiceInputFromUser() =
    voiceEntryActionHandler.toggleVoiceInputFromUser()

fun AssistantViewModel.speakVoicePrompt(text: String) =
    localPromptActionHandler.speakVoicePrompt(text)

internal fun AssistantViewModel.playBackendAssistantPromptFully(prompt: String?) =
    localPromptActionHandler.playBackendAssistantPromptFully(prompt)

internal fun AssistantViewModel.resumeVoiceSelectionListeningAfterPrompt() =
    localPromptActionHandler.resumeVoiceSelectionListeningAfterPrompt()

internal fun AssistantViewModel.presentSyntheticAssistantQuestion(
    text: String,
    restartRealtimeAfterPlayback: Boolean = false
) = localPromptActionHandler.presentSyntheticAssistantQuestion(
    text = text,
    restartRealtimeAfterPlayback = restartRealtimeAfterPlayback
)

fun AssistantViewModel.dismissAiCallPage() =
    callActionHandler.dismissAiCallPage()

fun AssistantViewModel.requestHumanTakeover() =
    callActionHandler.requestHumanTakeover()

fun AssistantViewModel.toggleCallMonitor() =
    callActionHandler.toggleCallMonitor()

fun AssistantViewModel.selectCallMonitorAudioRoute(route: CallMonitorAudioRoute) =
    callActionHandler.selectCallMonitorAudioRoute(route)

fun AssistantViewModel.setHumanTakeoverSoundEnabled(enabled: Boolean) =
    callActionHandler.setHumanTakeoverSoundEnabled(enabled)

fun AssistantViewModel.setHumanTakeoverSpeakerEnabled(enabled: Boolean) =
    callActionHandler.setHumanTakeoverSpeakerEnabled(enabled)

fun AssistantViewModel.releaseToAi() =
    callActionHandler.releaseToAi()

fun AssistantViewModel.hangUpCall(onFinished: (() -> Unit)? = null) =
    callActionHandler.hangUpCall(onFinished = onFinished)

internal fun AssistantViewModel.handleTakeoverAudioEvent(event: TakeoverAudioSocketClient.Event) =
    callActionHandler.handleTakeoverAudioEvent(event)

internal fun AssistantViewModel.scheduleTakeoverReconnect(delayMillis: Long = 450L) =
    callActionHandler.scheduleTakeoverReconnect(delayMillis)

internal fun AssistantViewModel.startCallSessionPolling() =
    callActionHandler.startCallSessionPolling()

internal fun AssistantViewModel.stopCallSessionPolling() =
    callActionHandler.stopCallSessionPolling()

fun AssistantViewModel.refreshCallSessionStatus() =
    callActionHandler.refreshCallSessionStatus()

internal fun AssistantViewModel.ensureTakeoverAudioSocket(taskId: String?, callId: String?) =
    callActionHandler.ensureTakeoverAudioSocket(taskId, callId)

internal fun AssistantViewModel.stopTakeoverAudioSocket() =
    callActionHandler.stopTakeoverAudioSocket()

internal fun AssistantViewModel.applyCallSessionStatus(
    response: CallSessionStatusResponse,
    appendNote: Boolean
) = callActionHandler.applyCallSessionStatus(response, appendNote)

internal fun AssistantViewModel.mergeCallTranscript(
    currentTranscript: List<TranscriptLine>,
    dialogueDetail: String?
): List<TranscriptLine> = callActionHandler.mergeCallTranscript(currentTranscript, dialogueDetail)

internal fun AssistantViewModel.shouldKeepPollingCallSession(state: Index9AssistantUiState): Boolean =
    callActionHandler.shouldKeepPollingCallSession(state)

internal fun AssistantViewModel.appendCallResult(result: ResultSummaryPayload) =
    callActionHandler.appendCallResult(result)

internal fun AssistantViewModel.appendCallNote(note: String) =
    callActionHandler.appendCallNote(note)

internal fun AssistantViewModel.appendClarificationStep(
    role: VoiceRole,
    text: String,
    isUserActionEcho: Boolean = false,
) = sessionMapper.appendClarificationStep(role, text, isUserActionEcho)

internal fun AssistantViewModel.snapshotVisibleClarificationSteps(
    state: Index9AssistantUiState
): List<ClarificationStep> = sessionMapper.snapshotVisibleClarificationSteps(state)

internal fun AssistantViewModel.commitVisibleAssistantTranscriptIfNeeded() =
    sessionMapper.commitVisibleAssistantTranscriptIfNeeded()
