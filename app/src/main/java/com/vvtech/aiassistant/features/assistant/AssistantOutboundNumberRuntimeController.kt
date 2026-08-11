package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class AssistantOutboundNumberRuntimeCallbacks(
    val onNavigateToDeveloperTools: () -> Unit
)

internal data class AssistantOutboundNumberRuntimeDeps(
    val context: Context,
    val taskRepository: TaskRepository,
    val scope: CoroutineScope
)

internal class AssistantOutboundNumberRuntimeState(
    val number: MutableState<String>,
    val draft: MutableState<String>,
    val error: MutableState<String?>,
    val loaded: MutableState<Boolean>,
    val configured: MutableState<Boolean>,
    val loading: MutableState<Boolean>,
    val saving: MutableState<Boolean>,
    val deleting: MutableState<Boolean>
)

internal class AssistantOutboundNumberRuntimeController(
    private val deps: AssistantOutboundNumberRuntimeDeps,
    private val state: AssistantOutboundNumberRuntimeState
) {
    var callbacks: AssistantOutboundNumberRuntimeCallbacks = AssistantOutboundNumberRuntimeCallbacks({})

    var number by state.number
    var draft by state.draft
    var error by state.error
    var loaded by state.loaded
    var configured by state.configured
    var loading by state.loading
    var saving by state.saving
    var deleting by state.deleting

    fun refresh(force: Boolean = false) {
        if (loading || (!force && loaded)) {
            logSettings("OUTBOUND_NUMBER_REFRESH_SKIPPED", "skipped", if (loading) "already_loading" else "already_loaded")
            return
        }
        deps.scope.launch {
            logSettings("OUTBOUND_NUMBER_REFRESH_STARTED")
            loading = true
            error = null
            runCatching {
                deps.taskRepository.getOutboundNumberSettings()
            }.onSuccess { response ->
                number = response.outboundNumber
                draft = response.outboundNumber
                configured = response.configured
                loaded = true
                logSettings("OUTBOUND_NUMBER_REFRESH_COMPLETED", "success")
            }.onFailure { throwable ->
                error = throwable.message ?: "固定外呼号码加载失败"
                logSettings("OUTBOUND_NUMBER_REFRESH_FAILED", "failed", throwable = throwable)
            }
            loading = false
        }
    }

    fun save() {
        val normalized = normalizeOutboundDialNumber(draft)
        if (normalized.isBlank()) {
            error = "请输入外呼号码"
            logSettings("OUTBOUND_NUMBER_SAVE_BLOCKED", "blocked", "number_blank")
            return
        }
        if (saving || deleting) {
            logSettings("OUTBOUND_NUMBER_SAVE_SKIPPED", "skipped", "operation_in_progress")
            return
        }
        deps.scope.launch {
            logSettings("OUTBOUND_NUMBER_SAVE_STARTED")
            saving = true
            error = null
            runCatching {
                deps.taskRepository.updateOutboundNumberSettings(normalized)
            }.onSuccess { response ->
                number = response.outboundNumber
                draft = response.outboundNumber
                configured = response.configured
                loaded = true
                logSettings("OUTBOUND_NUMBER_SAVE_COMPLETED", "success")
                Toast.makeText(deps.context, "固定外呼号码已保存", Toast.LENGTH_SHORT).show()
                callbacks.onNavigateToDeveloperTools()
            }.onFailure { throwable ->
                error = throwable.message ?: "固定外呼号码保存失败"
                logSettings("OUTBOUND_NUMBER_SAVE_FAILED", "failed", throwable = throwable)
            }
            saving = false
        }
    }

    fun delete() {
        if (number.isBlank() || saving || deleting) {
            logSettings(
                "OUTBOUND_NUMBER_DELETE_SKIPPED",
                "skipped",
                if (number.isBlank()) "number_blank" else "operation_in_progress"
            )
            return
        }
        deps.scope.launch {
            logSettings("OUTBOUND_NUMBER_DELETE_STARTED")
            deleting = true
            error = null
            runCatching {
                deps.taskRepository.deleteOutboundNumberSettings()
            }.onSuccess { response ->
                number = response.outboundNumber
                draft = response.outboundNumber
                configured = response.configured
                loaded = true
                logSettings("OUTBOUND_NUMBER_DELETE_COMPLETED", "success")
                Toast.makeText(deps.context, "固定外呼号码已删除", Toast.LENGTH_SHORT).show()
                callbacks.onNavigateToDeveloperTools()
            }.onFailure { throwable ->
                error = throwable.message ?: "固定外呼号码删除失败"
                logSettings("OUTBOUND_NUMBER_DELETE_FAILED", "failed", throwable = throwable)
            }
            deleting = false
        }
    }

    private fun logSettings(
        eventType: String,
        result: String? = null,
        reason: String? = null,
        throwable: Throwable? = null
    ) {
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.SETTINGS,
            eventType = eventType,
            result = result,
            reason = reason,
            attributes = mapOf("configured" to configured.toString())
        )
        if (throwable == null) RuntimeStateLogger.info(event) else RuntimeStateLogger.warn(event, throwable)
    }
}

@Composable
internal fun rememberAssistantOutboundNumberRuntimeController(
    deps: AssistantOutboundNumberRuntimeDeps,
    callbacks: AssistantOutboundNumberRuntimeCallbacks
): AssistantOutboundNumberRuntimeController {
    val state = AssistantOutboundNumberRuntimeState(
        number = rememberSaveable { mutableStateOf("") },
        draft = rememberSaveable { mutableStateOf("") },
        error = rememberSaveable { mutableStateOf<String?>(null) },
        loaded = rememberSaveable { mutableStateOf(false) },
        configured = rememberSaveable { mutableStateOf(false) },
        loading = rememberSaveable { mutableStateOf(false) },
        saving = rememberSaveable { mutableStateOf(false) },
        deleting = rememberSaveable { mutableStateOf(false) }
    )
    val controller = remember(deps.context, deps.taskRepository, deps.scope) {
        AssistantOutboundNumberRuntimeController(deps, state)
    }
    controller.callbacks = callbacks
    return controller
}
