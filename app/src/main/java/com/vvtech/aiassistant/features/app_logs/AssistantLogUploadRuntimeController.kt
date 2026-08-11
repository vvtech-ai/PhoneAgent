package com.vvtech.aiassistant.features.app_logs

import android.content.Context
import android.os.Build
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class AssistantLogUploadRuntimeController(
    private val state: AssistantLogUploadRuntimeState,
    private val deps: AssistantLogUploadRuntimeDeps
) {
    var logUploadInProgress by state.logUploadInProgress

    fun uploadAppLogs() {
        if (logUploadInProgress) {
            logUpload("LOG_UPLOAD_SKIPPED", "skipped", "already_uploading")
            return
        }
        val startedAt = System.currentTimeMillis()
        logUpload("LOG_UPLOAD_STARTED", "started", "user_requested")
        logUploadInProgress = true
        deps.scope.launch {
            runCatching {
                val zipFile = AppFileLogger.exportLogs(deps.context)
                val response = deps.taskRepository.uploadAppLogs(
                    zipFile = zipFile,
                    deviceInfo = buildString {
                        append(Build.MANUFACTURER).append(' ')
                        append(Build.MODEL).append(" / Android ")
                        append(Build.VERSION.RELEASE).append(" / ")
                        append(BuildConfig.VERSION_NAME).append('(').append(BuildConfig.VERSION_CODE).append(')')
                    }
                )
                AppFileLogger.clearLogs(deps.context)
                runCatching { zipFile.delete() }
                response
            }.onSuccess { response ->
                logUpload(
                    eventType = "LOG_UPLOAD_COMPLETED",
                    result = "completed",
                    reason = "upload_success",
                    elapsedMs = System.currentTimeMillis() - startedAt,
                    attributes = mapOf("storedFileNamePresent" to response.originalFileName.isNotBlank().toString())
                )
                Toast.makeText(
                    deps.context,
                    "日志上传成功：" + response.originalFileName,
                    Toast.LENGTH_SHORT
                ).show()
            }.onFailure { throwable ->
                logUpload(
                    eventType = "LOG_UPLOAD_FAILED",
                    result = "failed",
                    reason = "upload_failure",
                    elapsedMs = System.currentTimeMillis() - startedAt,
                    throwable = throwable
                )
                Toast.makeText(
                    deps.context,
                    "日志上传失败：" + (throwable.message ?: "未知错误"),
                    Toast.LENGTH_SHORT
                ).show()
            }
            logUploadInProgress = false
        }
    }

    private fun logUpload(
        eventType: String,
        result: String,
        reason: String,
        elapsedMs: Long? = null,
        attributes: Map<String, String?> = emptyMap(),
        throwable: Throwable? = null
    ) {
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.LOG_EXPORT,
            eventType = eventType,
            result = result,
            reason = reason,
            elapsedMs = elapsedMs,
            attributes = attributes + ("exceptionType" to throwable?.javaClass?.simpleName)
        )
        if (throwable == null) RuntimeStateLogger.info(event) else RuntimeStateLogger.warn(event, throwable)
    }
}

internal class AssistantLogUploadRuntimeState(
    val logUploadInProgress: MutableState<Boolean>
)

internal data class AssistantLogUploadRuntimeDeps(
    val context: Context,
    val taskRepository: TaskRepository,
    val scope: CoroutineScope
)

@Composable
internal fun rememberAssistantLogUploadRuntimeController(
    deps: AssistantLogUploadRuntimeDeps
): AssistantLogUploadRuntimeController {
    val state = AssistantLogUploadRuntimeState(
        logUploadInProgress = rememberSaveable { mutableStateOf(false) }
    )
    return remember(deps.context, deps.taskRepository, deps.scope) {
        AssistantLogUploadRuntimeController(state, deps)
    }
}
