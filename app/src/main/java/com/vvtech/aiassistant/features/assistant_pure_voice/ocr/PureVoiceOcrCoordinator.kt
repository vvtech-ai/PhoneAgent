package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.content.Context
import android.net.Uri
import android.os.SystemClock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import com.vvtech.aiassistant.logging.AppFileLogger
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal class PureVoiceOcrCoordinator(
    private val scope: CoroutineScope,
    private val processor: PureVoiceOcrProcessor,
    private val hostCallbacks: () -> PureVoiceOcrHostCallbacks?
) {
    private val mutableState = MutableStateFlow(PureVoiceOcrUiState())
    val state: StateFlow<PureVoiceOcrUiState> = mutableState.asStateFlow()

    private var activeJob: Job? = null
    private var jobGeneration = 0L
    private var nextOrdinal = 0L
    private var entryInitialized = false
    private var currentEntryKey: Any? = null

    fun selectImage(
        imageUri: Uri,
        anchorStepCount: Int,
        taskId: String?,
    ) {
        if (activeJob?.isActive == true) return

        val attachment = PureVoiceOcrAttachment(
            attachmentId = "ocr-${UUID.randomUUID()}",
            imageUri = imageUri,
            anchorStepCount = anchorStepCount.coerceAtLeast(0),
            createdOrdinal = nextOrdinal++,
            status = PureVoiceOcrStatus.Processing,
        )
        mutableState.value = PureVoiceOcrStateReducer.appendProcessing(
            mutableState.value,
            attachment
        )
        logStatus(attachment, taskId, "processing")

        val generation = ++jobGeneration
        activeJob = scope.launch {
            val startedAt = SystemClock.elapsedRealtime()
            var resolvedSessionId = taskId
            try {
                val completed = when (val recognition = recognize(attachment)) {
                    is LocalRecognitionOutcome.Failed -> recognition.attachment
                    is LocalRecognitionOutcome.Recognized -> {
                        val callbacks = requireNotNull(hostCallbacks()) {
                            "OCR cloud commit is unavailable"
                        }
                        resolvedSessionId = taskId?.takeIf(String::isNotBlank)
                            ?: callbacks.ensureSessionId()
                        commit(
                            callbacks = callbacks,
                            sessionId = resolvedSessionId.orEmpty(),
                            attachment = attachment,
                            recognition = recognition.value,
                        )
                    }
                }
                mutableState.value = PureVoiceOcrStateReducer.replaceAttachment(
                    mutableState.value,
                    completed
                )
                publishContext()
                logStatus(
                    attachment = completed,
                    taskId = resolvedSessionId,
                    status = completed.status.name.lowercase(),
                    durationMs = SystemClock.elapsedRealtime() - startedAt
                )
            } catch (throwable: Throwable) {
                if (throwable is CancellationException) throw throwable
                val failed = attachment.copy(
                    status = PureVoiceOcrStatus.Failed,
                    failure = (throwable as? PureVoiceOcrCommitException)?.failure
                        ?: PureVoiceOcrFailure.CloudCommitFailed
                )
                mutableState.value = PureVoiceOcrStateReducer.replaceAttachment(
                    mutableState.value,
                    failed
                )
                publishContext()
                logStatus(
                    attachment = failed,
                    taskId = resolvedSessionId,
                    status = if (failed.failure == PureVoiceOcrFailure.AiRefinementFailed) {
                        "ai_refinement_failed"
                    } else {
                        "cloud_commit_failed"
                    },
                    durationMs = SystemClock.elapsedRealtime() - startedAt
                )
            } finally {
                if (jobGeneration == generation) activeJob = null
            }
        }
    }

    suspend fun synchronizeHistory(
        entryKey: Any?,
        history: List<PureVoiceOcrHistoryAttachment>
    ) {
        if (!entryInitialized || currentEntryKey != entryKey) {
            resetForEntry(entryKey)
        }
        val ordered = PureVoiceOcrDisplayOrdering.ordered(history)
        val restoredNextOrdinal = ordered.maxOfOrNull { it.createdOrdinal + 1L } ?: 0L
        nextOrdinal = maxOf(nextOrdinal, restoredNextOrdinal)
        ordered.forEach { committed ->
            val current = mutableState.value.attachments.firstOrNull {
                it.attachmentId == committed.attachmentId
            }
            val imageUri = current?.imageUri ?: loadHistoryImage(committed) ?: return@forEach
            val restored = PureVoiceOcrAttachment(
                attachmentId = committed.attachmentId,
                imageUri = imageUri,
                anchorStepCount = committed.anchorStepCount,
                createdOrdinal = committed.createdOrdinal,
                status = PureVoiceOcrStatus.Success,
                segments = committed.segments,
                fields = committed.fields,
                fullText = committed.fullText
            )
            mutableState.value = PureVoiceOcrStateReducer.upsertCommitted(
                mutableState.value,
                restored
            )
            logStatus(restored, committed.sessionId, "history_restored")
        }
        publishContext()
    }

    fun close() {
        jobGeneration++
        activeJob?.cancel()
        activeJob = null
        processor.close()
        hostCallbacks()?.onContextChanged?.invoke(emptyList())
    }

    private suspend fun recognize(
        attachment: PureVoiceOcrAttachment
    ): LocalRecognitionOutcome {
        return try {
            val recognition = processor.recognize(attachment.imageUri)
            if (recognition.rawText.isBlank()) {
                LocalRecognitionOutcome.Failed(
                    attachment.copy(
                        status = PureVoiceOcrStatus.Failed,
                        failure = PureVoiceOcrFailure.EmptyText
                    )
                )
            } else {
                LocalRecognitionOutcome.Recognized(recognition)
            }
        } catch (throwable: Throwable) {
            if (throwable is CancellationException) throw throwable
            LocalRecognitionOutcome.Failed(
                attachment.copy(
                    status = PureVoiceOcrStatus.Failed,
                    failure = PureVoiceOcrFailure.RecognitionFailed
                )
            )
        }
    }

    private suspend fun commit(
        callbacks: PureVoiceOcrHostCallbacks,
        sessionId: String,
        attachment: PureVoiceOcrAttachment,
        recognition: PureVoiceOcrRecognition,
    ): PureVoiceOcrAttachment {
        val result = callbacks.commitAttachment(
            PureVoiceOcrCommitInput(
                sessionId = sessionId,
                attachmentId = attachment.attachmentId,
                imageUri = attachment.imageUri,
                anchorStepCount = attachment.anchorStepCount,
                createdOrdinal = attachment.createdOrdinal,
                initialOpening = callbacks.pendingInitialOpening(sessionId),
                rawSegments = recognition.rawSegments,
                rawText = recognition.rawText,
            )
        )
        check(result.attachmentId == attachment.attachmentId) {
            "OCR attachment response identity mismatch"
        }
        return attachment.copy(
            anchorStepCount = result.anchorStepCount,
            createdOrdinal = result.createdOrdinal,
            segments = result.segments,
            fields = result.fields,
            fullText = result.fullText,
            status = PureVoiceOcrStatus.Success,
            failure = null,
        )
    }

    private suspend fun loadHistoryImage(
        attachment: PureVoiceOcrHistoryAttachment
    ): Uri? {
        val callbacks = hostCallbacks() ?: return null
        val startedAt = SystemClock.elapsedRealtime()
        return try {
            callbacks.loadHistoryImage(attachment)
        } catch (throwable: Throwable) {
            if (throwable is CancellationException) throw throwable
            AppFileLogger.w(
                TAG,
                "attachmentId=${attachment.attachmentId} taskId=${attachment.sessionId} " +
                    "status=history_image_failed durationMs=${SystemClock.elapsedRealtime() - startedAt}"
            )
            null
        }
    }

    private fun resetForEntry(entryKey: Any?) {
        jobGeneration++
        activeJob?.cancel()
        activeJob = null
        currentEntryKey = entryKey
        entryInitialized = true
        nextOrdinal = 0L
        mutableState.value = PureVoiceOcrUiState()
        hostCallbacks()?.onContextChanged?.invoke(emptyList())
    }

    private fun publishContext() {
        hostCallbacks()?.onContextChanged?.invoke(
            PureVoiceOcrStateReducer.successfulContextPayloads(mutableState.value)
        )
    }

    private fun logStatus(
        attachment: PureVoiceOcrAttachment,
        taskId: String?,
        status: String,
        durationMs: Long? = null
    ) {
        AppFileLogger.i(
            TAG,
            buildString {
                append("attachmentId=${attachment.attachmentId}")
                append(" taskId=${taskId ?: "-"}")
                append(" status=$status")
                append(" anchorStepCount=${attachment.anchorStepCount}")
                append(" createdOrdinal=${attachment.createdOrdinal}")
                durationMs?.let { append(" durationMs=$it") }
                append(" segmentCount=${attachment.segments.size}")
                append(" fieldCount=${attachment.fields.size}")
                append(" textCharCount=${attachment.fullText.length}")
                attachment.failure?.let { append(" failureCode=${it.name}") }
            }
        )
    }

    private companion object {
        const val TAG = "PURE_VOICE_OCR"
    }

    private sealed interface LocalRecognitionOutcome {
        data class Recognized(val value: PureVoiceOcrRecognition) : LocalRecognitionOutcome
        data class Failed(val attachment: PureVoiceOcrAttachment) : LocalRecognitionOutcome
    }
}

@Composable
internal fun rememberPureVoiceOcrCoordinator(
    context: Context,
    scope: CoroutineScope,
    entryKey: Any?,
    history: List<PureVoiceOcrHistoryAttachment>,
    hostCallbacks: PureVoiceOcrHostCallbacks?
): PureVoiceOcrCoordinator {
    val currentHostCallbacks = rememberUpdatedState(hostCallbacks)
    val coordinator = remember(context.applicationContext, scope) {
        PureVoiceOcrCoordinator(
            scope = scope,
            processor = MlKitPureVoiceOcrProcessor(context),
            hostCallbacks = { currentHostCallbacks.value }
        )
    }

    LaunchedEffect(entryKey, history, hostCallbacks != null) {
        coordinator.synchronizeHistory(entryKey, history)
    }
    DisposableEffect(coordinator) {
        onDispose(coordinator::close)
    }
    return coordinator
}
