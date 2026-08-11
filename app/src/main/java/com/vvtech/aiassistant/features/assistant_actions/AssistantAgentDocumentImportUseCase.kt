package com.vvtech.aiassistant.features.assistant_actions

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.data.repository.AssistantRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal class AssistantAgentDocumentImportUseCase(
    private val context: Context,
    private val repository: AssistantRepository
) {
    fun cancelledResult(): DocumentParseResult {
        return DocumentParseResult(
            status = "USER_CANCELLED",
            message = "用户取消了文件选择"
        )
    }

    suspend fun parse(uri: Uri, maxBytes: Long?): DocumentParseResult {
        return withContext(Dispatchers.IO) {
            runCatching {
                val fileName = displayNameForUri(uri).ifBlank { DefaultAgentDocumentFileName }
                val mimeType = context.contentResolver.getType(uri)
                val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalStateException("无法读取所选文件")
                val limit = maxBytes ?: DefaultAgentDocumentMaxBytes
                if (bytes.size.toLong() > limit) {
                    DocumentParseResult(
                        status = "FILE_TOO_LARGE",
                        fileName = fileName,
                        mimeType = mimeType,
                        message = "文件超过 ${limit / 1024 / 1024}MB 限制"
                    )
                } else {
                    repository.parseDocument(fileName, mimeType, bytes)
                }
            }.getOrElse { throwable ->
                DocumentParseResult(
                    status = "PARSE_FAILED",
                    message = throwable.message ?: "文件读取失败"
                )
            }
        }
    }

    private fun displayNameForUri(uri: Uri): String {
        return runCatching {
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index).orEmpty() else ""
            }.orEmpty()
        }.getOrDefault("")
    }
}

private const val DefaultAgentDocumentFileName = "document.txt"
private const val DefaultAgentDocumentMaxBytes = 5L * 1024L * 1024L
