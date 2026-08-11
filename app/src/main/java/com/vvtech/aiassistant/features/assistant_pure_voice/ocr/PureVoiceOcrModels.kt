package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.net.Uri
import com.vvtech.aiassistant.model.OcrAttachmentContextPayload
import com.vvtech.aiassistant.model.OcrContextFieldPayload

internal enum class PureVoiceOcrStatus {
    Processing,
    Success,
    Failed
}

internal enum class PureVoiceOcrFailure {
    EmptyText,
    RecognitionFailed,
    AiRefinementFailed,
    CloudCommitFailed
}

internal data class PureVoiceOcrField(
    val key: String,
    val label: String,
    val value: String
)

internal interface PureVoiceOcrOrdered {
    val anchorStepCount: Int
    val createdOrdinal: Long
}

internal data class PureVoiceOcrAttachment(
    val attachmentId: String,
    val imageUri: Uri,
    override val anchorStepCount: Int,
    override val createdOrdinal: Long,
    val status: PureVoiceOcrStatus,
    val segments: List<String> = emptyList(),
    val fields: List<PureVoiceOcrField> = emptyList(),
    val fullText: String = "",
    val failure: PureVoiceOcrFailure? = null,
) : PureVoiceOcrOrdered

internal data class PureVoiceOcrUiState(
    val attachments: List<PureVoiceOcrAttachment> = emptyList(),
    val processingAttachmentId: String? = null
) {
    val isProcessing: Boolean
        get() = processingAttachmentId != null
}

internal data class PureVoiceOcrCallbacks(
    val onImageSelected: (Uri) -> Unit
)

internal data class PureVoiceOcrHostCallbacks(
    val onContextChanged: (List<OcrAttachmentContextPayload>) -> Unit,
    val ensureSessionId: () -> String,
    val pendingInitialOpening: (String) -> String?,
    val commitAttachment: suspend (PureVoiceOcrCommitInput) -> PureVoiceOcrCommitResult,
    val loadHistoryImage: suspend (PureVoiceOcrHistoryAttachment) -> Uri,
)

internal data class PureVoiceOcrBinding(
    val state: PureVoiceOcrUiState,
    val callbacks: PureVoiceOcrCallbacks
)

internal data class PureVoiceOcrRecognition(
    val rawSegments: List<String>,
    val rawText: String
)

internal data class PureVoiceOcrCommitInput(
    val sessionId: String,
    val attachmentId: String,
    val imageUri: Uri,
    val anchorStepCount: Int,
    val createdOrdinal: Long,
    val initialOpening: String?,
    val rawSegments: List<String>,
    val rawText: String,
)

internal data class PureVoiceOcrCommitResult(
    val attachmentId: String,
    val anchorStepCount: Int,
    val createdOrdinal: Long,
    val segments: List<String>,
    val fields: List<PureVoiceOcrField>,
    val fullText: String,
)

internal class PureVoiceOcrCommitException(
    val failure: PureVoiceOcrFailure,
    cause: Throwable? = null,
) : IllegalStateException(failure.name, cause)

internal data class PureVoiceOcrHistoryAttachment(
    val sessionId: String,
    val attachmentId: String,
    val contentPath: String,
    val contentType: String,
    override val anchorStepCount: Int,
    override val createdOrdinal: Long,
    val segments: List<String>,
    val fields: List<PureVoiceOcrField>,
    val fullText: String,
) : PureVoiceOcrOrdered

internal interface PureVoiceOcrProcessor {
    suspend fun recognize(imageUri: Uri): PureVoiceOcrRecognition
    fun close() = Unit
}

internal object PureVoiceOcrDisplayOrdering {
    fun <T : PureVoiceOcrOrdered> ordered(items: List<T>): List<T> =
        items.sortedBy(PureVoiceOcrOrdered::createdOrdinal)

    fun <T : PureVoiceOcrOrdered> byAnchor(
        items: List<T>,
        displayStepCount: Int,
    ): Map<Int, List<T>> = ordered(items).groupBy { item ->
        item.anchorStepCount.coerceIn(0, displayStepCount)
    }
}

internal object PureVoiceOcrStateReducer {
    fun appendProcessing(
        state: PureVoiceOcrUiState,
        attachment: PureVoiceOcrAttachment
    ): PureVoiceOcrUiState {
        return state.copy(
            attachments = state.attachments + attachment,
            processingAttachmentId = attachment.attachmentId
        )
    }

    fun replaceAttachment(
        state: PureVoiceOcrUiState,
        attachment: PureVoiceOcrAttachment
    ): PureVoiceOcrUiState {
        return state.copy(
            attachments = state.attachments.map { current ->
                if (current.attachmentId == attachment.attachmentId) attachment else current
            },
            processingAttachmentId = state.processingAttachmentId
                ?.takeUnless { it == attachment.attachmentId }
        )
    }

    fun upsertCommitted(
        state: PureVoiceOcrUiState,
        attachment: PureVoiceOcrAttachment
    ): PureVoiceOcrUiState {
        val current = state.attachments.firstOrNull {
            it.attachmentId == attachment.attachmentId
        }
        val committed = current?.let {
            attachment.copy(
                imageUri = it.imageUri,
                // Selection time is authoritative even when the OCR event commits later.
                anchorStepCount = it.anchorStepCount,
            )
        } ?: attachment
        val next = if (current == null) {
            state.attachments + committed
        } else {
            state.attachments.map {
                if (it.attachmentId == committed.attachmentId) committed else it
            }
        }
        return state.copy(
            attachments = PureVoiceOcrDisplayOrdering.ordered(next),
            processingAttachmentId = state.processingAttachmentId
                ?.takeUnless { it == committed.attachmentId }
        )
    }

    fun successfulContextPayloads(
        state: PureVoiceOcrUiState
    ): List<OcrAttachmentContextPayload> {
        return PureVoiceOcrDisplayOrdering.ordered(state.attachments)
            .filter { it.status == PureVoiceOcrStatus.Success }
            .map { attachment ->
                OcrAttachmentContextPayload(
                    attachmentId = attachment.attachmentId,
                    fields = attachment.fields.map { field ->
                        OcrContextFieldPayload(
                            label = field.label,
                            value = field.value
                        )
                    },
                    segments = attachment.segments,
                    fullText = attachment.fullText
                )
            }
    }
}
