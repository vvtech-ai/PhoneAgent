package com.vvtech.aiassistant.data.repository.ocr

import com.google.gson.Gson
import com.vvtech.aiassistant.data.remote.ocr.ConversationOcrAttachmentApi
import com.vvtech.aiassistant.data.remote.ocr.ConversationOcrCommitMetadataDto
import com.vvtech.aiassistant.data.remote.ocr.ConversationOcrCommitResponseDto
import com.vvtech.aiassistant.data.remote.ocr.ConversationOcrFieldDto
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.HttpException

data class ConversationOcrUpload(
    val sessionId: String,
    val attachmentId: String,
    val imageBytes: ByteArray,
    val fileName: String,
    val contentType: String,
    val anchorStepCount: Int,
    val createdOrdinal: Long,
    val initialOpening: String?,
    val rawSegments: List<String>,
    val rawText: String,
)

data class ConversationOcrUploadField(
    val label: String,
    val value: String,
)

data class ConversationOcrCommitResult(
    val attachmentId: String,
    val sessionId: String,
    val contentPath: String,
    val contentType: String,
    val anchorStepCount: Int,
    val createdOrdinal: Long,
    val fields: List<ConversationOcrUploadField>,
    val segments: List<String>,
    val fullText: String,
)

class ConversationOcrAttachmentRepository(
    private val api: ConversationOcrAttachmentApi,
    private val gson: Gson = Gson(),
) {
    suspend fun commit(upload: ConversationOcrUpload): ConversationOcrCommitResult {
        val imageBody = upload.imageBytes.toRequestBody(upload.contentType.toMediaType())
        val imagePart = MultipartBody.Part.createFormData("image", upload.fileName, imageBody)
        val metadata = metadata(upload)
        val response = try {
            api.commit(
                sessionId = upload.sessionId,
                image = imagePart,
                metadata = gson.toJson(metadata).toRequestBody(JSON_MEDIA_TYPE),
            )
        } catch (failure: HttpException) {
            throw remoteException(failure)
        }
        val committed = response.data
        if (response.code != 0 || committed == null) {
            throw ConversationOcrRemoteException(
                errorCode = response.message,
                message = response.message.ifBlank { "OCR attachment commit failed" },
            )
        }
        return committed.toResult()
    }

    suspend fun loadContent(sessionId: String, attachmentId: String): ByteArray {
        val response = api.content(sessionId, attachmentId)
        if (!response.isSuccessful) {
            response.errorBody()?.close()
            throw ConversationOcrRemoteException(
                errorCode = "",
                message = "OCR attachment content failed: HTTP ${response.code()}",
            )
        }
        return response.body()?.use { it.bytes() }
            ?: throw ConversationOcrRemoteException(
                errorCode = "",
                message = "OCR attachment content is empty",
            )
    }

    private fun metadata(upload: ConversationOcrUpload): ConversationOcrCommitMetadataDto =
        ConversationOcrCommitMetadataDto(
            attachmentId = upload.attachmentId,
            commandId = "ocr-command-${upload.attachmentId.removePrefix("ocr-")}",
            idempotencyKey = "ocr:${upload.sessionId}:${upload.attachmentId}",
            traceId = "ocr-trace-${upload.attachmentId.removePrefix("ocr-")}",
            anchorStepCount = upload.anchorStepCount,
            createdOrdinal = upload.createdOrdinal,
            initialOpening = upload.initialOpening,
            rawSegments = upload.rawSegments,
            rawText = upload.rawText,
        )

    private fun remoteException(failure: HttpException): ConversationOcrRemoteException {
        val errorBody = failure.response()?.errorBody()?.string()
        val errorCode = runCatching {
            gson.fromJson(errorBody, OcrErrorResponse::class.java)?.message
        }.getOrNull().orEmpty()
        return ConversationOcrRemoteException(
            errorCode = errorCode,
            message = errorCode.ifBlank {
                "OCR attachment commit failed: HTTP ${failure.code()}"
            },
        )
    }

    private fun ConversationOcrCommitResponseDto.toResult() = ConversationOcrCommitResult(
        attachmentId = attachmentId,
        sessionId = sessionId,
        contentPath = contentPath,
        contentType = contentType,
        anchorStepCount = anchorStepCount,
        createdOrdinal = createdOrdinal,
        fields = fields.map { ConversationOcrUploadField(it.label, it.value) },
        segments = segments,
        fullText = fullText,
    )

    private companion object {
        val JSON_MEDIA_TYPE = "application/json".toMediaType()
    }
}

private data class OcrErrorResponse(val message: String?)

class ConversationOcrRemoteException(
    val errorCode: String,
    message: String,
) : IllegalStateException(message)
