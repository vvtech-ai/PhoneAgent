package com.vvtech.aiassistant.features.assistant_pure_voice.ocr

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.vvtech.aiassistant.data.repository.ocr.ConversationOcrAttachmentRepository
import com.vvtech.aiassistant.data.repository.ocr.ConversationOcrRemoteException
import com.vvtech.aiassistant.data.repository.ocr.ConversationOcrUpload
import java.io.ByteArrayOutputStream
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal class PureVoiceOcrAttachmentHandler(
    context: Context,
    private val repository: ConversationOcrAttachmentRepository,
) {
    private val appContext = context.applicationContext

    suspend fun commit(input: PureVoiceOcrCommitInput): PureVoiceOcrCommitResult =
        withContext(Dispatchers.IO) {
            val source = readSource(input.imageUri)
            val committed = try {
                repository.commit(
                    ConversationOcrUpload(
                        sessionId = input.sessionId,
                        attachmentId = input.attachmentId,
                        imageBytes = source.bytes,
                        fileName = source.fileName,
                        contentType = source.contentType,
                        anchorStepCount = input.anchorStepCount,
                        createdOrdinal = input.createdOrdinal,
                        initialOpening = input.initialOpening,
                        rawSegments = input.rawSegments,
                        rawText = input.rawText,
                    )
                )
            } catch (failure: ConversationOcrRemoteException) {
                val mapped = if (failure.errorCode == OCR_AI_REFINEMENT_FAILED) {
                    PureVoiceOcrFailure.AiRefinementFailed
                } else {
                    PureVoiceOcrFailure.CloudCommitFailed
                }
                throw PureVoiceOcrCommitException(mapped, failure)
            }
            PureVoiceOcrCommitResult(
                attachmentId = committed.attachmentId,
                anchorStepCount = committed.anchorStepCount,
                createdOrdinal = committed.createdOrdinal,
                fields = committed.fields.mapIndexed { index, field ->
                    PureVoiceOcrField(
                        key = "${committed.attachmentId}:field:$index",
                        label = field.label,
                        value = field.value,
                    )
                },
                segments = committed.segments,
                fullText = committed.fullText,
            )
        }

    suspend fun loadHistoryImage(attachment: PureVoiceOcrHistoryAttachment): Uri =
        withContext(Dispatchers.IO) {
            val target = cacheFile(attachment)
            if (!target.isFile || target.length() == 0L) {
                val bytes = repository.loadContent(
                    sessionId = attachment.sessionId,
                    attachmentId = attachment.attachmentId,
                )
                require(bytes.isNotEmpty()) { "OCR attachment content is empty" }
                writeAtomically(target, bytes)
            }
            Uri.fromFile(target)
        }

    private fun readSource(uri: Uri): UploadSource {
        val resolver = appContext.contentResolver
        val bytes = resolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                require(total <= MAX_IMAGE_BYTES) { "OCR image exceeds 10 MiB" }
                output.write(buffer, 0, read)
            }
            output.toByteArray()
        } ?: throw IllegalStateException("OCR image cannot be opened")
        require(bytes.isNotEmpty()) { "OCR image is empty" }
        return UploadSource(
            bytes = bytes,
            fileName = displayName(uri) ?: "ocr-image",
            contentType = resolver.getType(uri)?.takeIf(String::isNotBlank)
                ?: "application/octet-stream",
        )
    }

    private fun displayName(uri: Uri): String? {
        return appContext.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
        }?.substringAfterLast('/')?.substringAfterLast('\\')?.takeIf(String::isNotBlank)
    }

    private fun cacheFile(attachment: PureVoiceOcrHistoryAttachment): File {
        val directory = File(
            appContext.cacheDir,
            "conversation-ocr/${attachment.sessionId.safePathPart()}",
        )
        check(directory.isDirectory || directory.mkdirs()) {
            "OCR attachment cache directory cannot be created"
        }
        val extension = when (attachment.contentType.lowercase().substringBefore(';')) {
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/heic" -> "heic"
            "image/heif" -> "heif"
            else -> "image"
        }
        return File(directory, "${attachment.attachmentId.safePathPart()}.$extension")
    }

    private fun writeAtomically(target: File, bytes: ByteArray) {
        val temporary = File(target.parentFile, "${target.name}.part")
        temporary.outputStream().use { it.write(bytes) }
        if (target.exists()) target.delete()
        if (!temporary.renameTo(target)) {
            temporary.copyTo(target, overwrite = true)
            temporary.delete()
        }
    }

    private fun String.safePathPart(): String =
        replace(Regex("[^A-Za-z0-9._-]"), "_")

    private data class UploadSource(
        val bytes: ByteArray,
        val fileName: String,
        val contentType: String,
    )

    private companion object {
        const val MAX_IMAGE_BYTES = 10 * 1024 * 1024
        const val OCR_AI_REFINEMENT_FAILED = "OCR_AI_REFINEMENT_FAILED"
    }
}
