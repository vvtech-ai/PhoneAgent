package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import android.os.SystemClock
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText

private const val RECOGNIZED_TURN_DEDUP_WINDOW_MS = 2_500L
private const val MAX_QUEUED_RECOGNIZED_TURNS = 3

private val RECOGNIZED_TURN_FINGERPRINT_IGNORED_CHARS =
    Regex("""[\s\p{Punct}，。！？、；：,.!?;:"'“”‘’（）()\[\]【】]+""")

internal class VoiceRecognizedTurnQueueController(
    private val viewModel: AssistantViewModel
) {
    private var lastRecognizedTurnFingerprint = ""
    private var lastRecognizedTurnAtMs = 0L
    private var lastRecognizedTurnGeneration = -1L

    fun resetDedup() {
        lastRecognizedTurnFingerprint = ""
        lastRecognizedTurnAtMs = 0L
        lastRecognizedTurnGeneration = -1L
    }

    fun enqueueRecognizedTurn(text: String) { with(viewModel) {
        val normalized = text.trim()
        if (normalized.isBlank()) {
            internalLog(
                "enqueueRecognizedTurn ignored blank runId=$activeDialogRunId scene=${internalUiState.value.sceneType} " +
                    "dialogKey=${activeDialogContext?.dialogKey}"
            )
            return
        }
        val fingerprint = recognizedTurnFingerprint(normalized)
        val now = SystemClock.elapsedRealtime()
        val inputGeneration = voiceRecognizedInputDedupTracker.currentGeneration()
        if (fingerprint.isNotBlank() &&
            fingerprint == lastRecognizedTurnFingerprint &&
            inputGeneration == lastRecognizedTurnGeneration &&
            now - lastRecognizedTurnAtMs <= RECOGNIZED_TURN_DEDUP_WINDOW_MS
        ) {
            internalLog(
                "enqueueRecognizedTurn ignored duplicate windowMs=${now - lastRecognizedTurnAtMs} " +
                    "generation=$inputGeneration " +
                    "text=${previewText(normalized)}"
            )
            return
        }
        val busy = pendingSpeechTurn?.isActive == true || internalUiState.value.processingTurn
        if (busy) {
            if (queuedRecognizedTurns.none { recognizedTurnFingerprint(it) == fingerprint }) {
                while (queuedRecognizedTurns.size >= MAX_QUEUED_RECOGNIZED_TURNS) {
                    queuedRecognizedTurns.pollFirst()
                }
                queuedRecognizedTurns.addLast(normalized)
                lastRecognizedTurnFingerprint = fingerprint
                lastRecognizedTurnAtMs = now
                lastRecognizedTurnGeneration = inputGeneration
                internalLog(
                    "enqueueRecognizedTurn queued runId=$activeDialogRunId scene=${internalUiState.value.sceneType} " +
                        "size=${queuedRecognizedTurns.size} processing=${internalUiState.value.processingTurn} " +
                        "text=${previewText(normalized)}"
                )
            } else {
                internalLog(
                    "enqueueRecognizedTurn ignored queued duplicate runId=$activeDialogRunId " +
                        "text=${previewText(normalized)}"
                )
            }
            return
        }
        lastRecognizedTurnFingerprint = fingerprint
        lastRecognizedTurnAtMs = now
        lastRecognizedTurnGeneration = inputGeneration
        internalLog(
            "enqueueRecognizedTurn immediate runId=$activeDialogRunId scene=${internalUiState.value.sceneType} " +
                "dialogKey=${activeDialogContext?.dialogKey} text=${previewText(normalized)}"
        )
        submitRecognizedTurn(normalized)
    } }

    private fun recognizedTurnFingerprint(text: String): String =
        text.trim()
            .lowercase()
            .replace(RECOGNIZED_TURN_FINGERPRINT_IGNORED_CHARS, "")
}
