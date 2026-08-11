package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceDuplexSpeechSource
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.localizedConfirmingDetailsStatus
import com.vvtech.aiassistant.features.assistant.localizedListeningStatus
import com.vvtech.aiassistant.features.assistant.localizedStatusHintOrFallback
import com.vvtech.aiassistant.features.assistant.viewmodel.detectLocalSceneHint
import com.vvtech.aiassistant.features.assistant.viewmodel.isBackendStateMachineScene
import com.vvtech.aiassistant.features.assistant.viewmodel.maxStage
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import kotlinx.coroutines.flow.update

internal interface VoiceRealtimeAssistantSpeechCallbacks {
    fun stopLiveTranscription(suppressRestart: Boolean)
    fun submitPendingStructuredTurn(understanding: StructuredAssistantUnderstanding?, reason: String): Boolean
    fun appendClarificationStep(role: VoiceRole, text: String)
    fun resumeListeningAfterTts()
}

internal class VoiceRealtimeAssistantSpeechHandler(
    private val viewModel: AssistantViewModel,
    private val callbacks: VoiceRealtimeAssistantSpeechCallbacks
) {
    fun handleRealtimeAssistantTranscript(text: String, definite: Boolean) { with(viewModel) {
        val normalized = text.trim()
        if (normalized.isBlank()) return
        if (looksLikeStructuredAssistantPayload(normalized)) {
            internalLog(
                "handleRealtimeAssistantTranscript ignored structured-like text " +
                    "runId=$activeDialogRunId definite=$definite text=${previewText(normalized)}"
            )
            return
        }
        val currentScene = activeDialogContext?.sceneType ?: internalUiState.value.sceneType
        if (isBackendStateMachineScene(currentScene)) {
            internalLog(
                "handleRealtimeAssistantTranscript ignored backendOwned scene=$currentScene " +
                    "runId=$activeDialogRunId definite=$definite text=${previewText(normalized)}"
            )
            return
        }
        val pendingBackendSceneHint = pendingStructuredRecognizedTurn
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?.let(::detectLocalSceneHint)
            ?.takeIf(::isBackendStateMachineScene)
        if (pendingBackendSceneHint != null) {
            submitBackendHint(normalized, definite, currentScene, pendingBackendSceneHint)
            return
        }
        internalLog(
            "handleRealtimeAssistantTranscript runId=$activeDialogRunId scene=$currentScene " +
                "dialogKey=${activeDialogContext?.dialogKey} definite=$definite text=${previewText(normalized)}"
        )
        internalUiState.update {
            it.copy(
                stage = maxStage(it.stage, AssistantStage.Clarifying),
                voiceConnecting = false,
                voiceActive = true,
                listening = false,
                processingTurn = false,
                liveAssistantTranscript = normalized,
                status = localizedListeningStatus()
            )
        }
        if (!definite) return
        latestRealtimeAssistantReplyForBackend = normalized
        if (normalized == lastCommittedAssistantTranscript) return
        lastCommittedAssistantTranscript = normalized
        callbacks.appendClarificationStep(VoiceRole.Assistant, normalized)
        localTtsPlaying = true
        internalUiState.update { it.copy(localTtsSpeaking = true) }
        voiceDuplexCoordinator.speakLocal(
            normalized,
            source = VoiceDuplexSpeechSource.RealtimeAssistant,
            languageCode = voiceLanguageCode,
            onDone = callbacks::resumeListeningAfterTts,
            onError = callbacks::resumeListeningAfterTts
        )
    } }

    fun handleRealtimeStructuredAssistantResponse(understanding: StructuredAssistantUnderstanding) { with(viewModel) {
        val speak = understanding.speak?.trim().orEmpty()
        val structuredScene = understanding.scene
            ?.trim()
            ?.uppercase()
            ?.takeIf { it.isNotBlank() }
        val pendingRecognized = pendingStructuredRecognizedTurn?.trim().orEmpty()
        val backendOwnedStructuredTurn = pendingRecognized.isNotBlank() &&
            isBackendStateMachineScene(structuredScene)
        internalLog(
            "handleRealtimeStructuredAssistantResponse runId=$activeDialogRunId " +
                "scene=${activeDialogContext?.sceneType} dialogKey=${activeDialogContext?.dialogKey} " +
                "voiceTaskId=$voiceTaskId uiTaskId=${internalUiState.value.taskId} " +
                "pendingText=${previewText(pendingStructuredRecognizedTurn.orEmpty())} " +
                "sceneResult=${understanding.scene} confidence=${understanding.sceneConfidence} " +
                "slotKeys=${understanding.slotUpdates.keys} speak=${previewText(speak)}"
        )
        if (backendOwnedStructuredTurn) {
            submitBackendOwnedStructured(understanding, structuredScene, pendingRecognized)
            return
        }
        if (speak.isNotBlank()) {
            showStructuredSpeak(understanding, speak)
        }
        callbacks.submitPendingStructuredTurn(understanding, reason = "structured_chat_response")
    } }

    private fun submitBackendHint(
        normalized: String,
        definite: Boolean,
        currentScene: String,
        pendingBackendSceneHint: String
    ) { with(viewModel) {
        suppressAssistantEventsForCurrentRun = true
        latestRealtimeAssistantReplyForBackend = null
        internalLog(
            "handleRealtimeAssistantTranscript backendHintSubmit runId=$activeDialogRunId " +
                "scene=$currentScene pendingSceneHint=$pendingBackendSceneHint " +
                "pendingText=${previewText(pendingStructuredRecognizedTurn.orEmpty())} " +
                "ignoredText=${previewText(normalized)} definite=$definite"
        )
        stopLiveIfActive()
        internalUiState.update {
            it.copy(
                stage = maxStage(it.stage, AssistantStage.Clarifying),
                voiceConnecting = false,
                listening = false,
                processingTurn = true,
                liveAssistantTranscript = null,
                status = localizedConfirmingDetailsStatus(pendingBackendSceneHint)
            )
        }
        callbacks.submitPendingStructuredTurn(null, reason = "assistant_transcript_backend_scene_hint")
    } }

    private fun submitBackendOwnedStructured(
        understanding: StructuredAssistantUnderstanding,
        structuredScene: String?,
        pendingRecognized: String
    ) { with(viewModel) {
        suppressAssistantEventsForCurrentRun = true
        latestRealtimeAssistantReplyForBackend = null
        internalLog(
            "handleRealtimeStructuredAssistantResponse backendOwnedSubmit runId=$activeDialogRunId " +
                "structuredScene=$structuredScene text=${previewText(pendingRecognized)}"
        )
        stopLiveIfActive()
        internalUiState.update {
            it.copy(
                stage = maxStage(it.stage, AssistantStage.Clarifying),
                voiceConnecting = false,
                listening = false,
                processingTurn = true,
                liveAssistantTranscript = null,
                status = localizedStatusHintOrFallback(
                    understanding.statusHint,
                    localizedConfirmingDetailsStatus(structuredScene)
                )
            )
        }
        callbacks.submitPendingStructuredTurn(understanding, reason = "structured_backend_state_machine")
    } }

    private fun showStructuredSpeak(understanding: StructuredAssistantUnderstanding, speak: String) { with(viewModel) {
        internalUiState.update {
            it.copy(
                stage = maxStage(it.stage, AssistantStage.Clarifying),
                voiceConnecting = false,
                voiceActive = true,
                listening = false,
                liveAssistantTranscript = speak,
                status = localizedStatusHintOrFallback(
                    understanding.statusHint,
                    localizedConfirmingDetailsStatus(activeDialogContext?.sceneType ?: internalUiState.value.sceneType)
                )
            )
        }
        if (speak == lastCommittedAssistantTranscript) return
        lastCommittedAssistantTranscript = speak
        callbacks.appendClarificationStep(VoiceRole.Assistant, speak)
        localTtsPlaying = true
        voiceDuplexCoordinator.speakLocal(
            speak,
            source = VoiceDuplexSpeechSource.StructuredSpeak,
            languageCode = voiceLanguageCode,
            onDone = callbacks::resumeListeningAfterTts,
            onError = callbacks::resumeListeningAfterTts
        )
    } }

    private fun stopLiveIfActive() { with(viewModel) {
        if (internalUiState.value.voiceActive || internalUiState.value.voiceConnecting) {
            callbacks.stopLiveTranscription(suppressRestart = true)
        }
    } }
}

private fun looksLikeStructuredAssistantPayload(text: String): Boolean {
    val trimmed = text.trim()
    return trimmed.startsWith("{") &&
        (trimmed.contains("\"scene\"") ||
            trimmed.contains("\"slotUpdates\"") ||
            trimmed.contains("\"speak\""))
}
