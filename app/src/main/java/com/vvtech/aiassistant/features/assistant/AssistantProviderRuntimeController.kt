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
import com.vvtech.aiassistant.features.assistant_model.AiCallModelLatencySource
import com.vvtech.aiassistant.features.assistant_model.aiCallModelLatencyReading
import com.vvtech.aiassistant.features.assistant_initialization.AssistantInitializationLoadState
import com.vvtech.aiassistant.features.assistant_initialization.assistantProviderLoadState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_settings.realtimeCallVoiceDisplayName
import com.vvtech.aiassistant.features.assistant_ui.AssistantCallModelDisplayNames
import com.vvtech.aiassistant.model.RealtimeCallProviderResponse
import com.vvtech.aiassistant.model.RealtimeCallVoiceResponse
import com.vvtech.aiassistant.model.RealtimeTranslationProviderResponse
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import com.vvtech.aiassistant.repository.TaskRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class AssistantProviderRuntimeCallbacks(
    val onRealtimeProviderChanged: () -> Unit,
    val onRealtimeCallVoiceChanged: () -> Unit
)

internal data class AssistantProviderRuntimeDeps(
    val context: Context,
    val taskRepository: TaskRepository,
    val scope: CoroutineScope
)

internal class AssistantProviderRuntimeState(
    val realtimeProviderResponse: MutableState<RealtimeCallProviderResponse?>,
    val realtimeProviderLoading: MutableState<Boolean>,
    val realtimeProviderSwitching: MutableState<Boolean>,
    val realtimeProviderError: MutableState<String?>,
    val realtimeCallVoiceResponse: MutableState<RealtimeCallVoiceResponse?>,
    val realtimeCallVoiceLoading: MutableState<Boolean>,
    val realtimeCallVoiceSwitching: MutableState<Boolean>,
    val realtimeCallVoiceError: MutableState<String?>,
    val translationProviderResponse: MutableState<RealtimeTranslationProviderResponse?>,
    val translationProviderLoading: MutableState<Boolean>,
    val translationProviderSwitching: MutableState<Boolean>,
    val translationProviderError: MutableState<String?>
)

internal class AssistantProviderRuntimeController(
    private val deps: AssistantProviderRuntimeDeps,
    private val state: AssistantProviderRuntimeState
) {
    var callbacks: AssistantProviderRuntimeCallbacks = AssistantProviderRuntimeCallbacks({}, {})

    val callModelLatencySource: AiCallModelLatencySource = AiCallModelLatencySource { modelIds ->
        val requested = modelIds.toSet()
        deps.taskRepository.getRealtimeCallModelLatencies(refresh = true).models
            .filter { it.provider in requested }
            .associate { item ->
                item.provider to aiCallModelLatencyReading(
                    available = item.available,
                    latencyMs = item.latencyMs
                )
            }
    }

    var realtimeProviderResponse: RealtimeCallProviderResponse?
        get() = state.realtimeProviderResponse.value
        set(value) {
            state.realtimeProviderResponse.value = value
        }
    var realtimeProviderLoading by state.realtimeProviderLoading
    var realtimeProviderSwitching by state.realtimeProviderSwitching
    var realtimeProviderError by state.realtimeProviderError

    var realtimeCallVoiceResponse: RealtimeCallVoiceResponse?
        get() = state.realtimeCallVoiceResponse.value
        set(value) {
            state.realtimeCallVoiceResponse.value = value
        }
    var realtimeCallVoiceLoading by state.realtimeCallVoiceLoading
    var realtimeCallVoiceSwitching by state.realtimeCallVoiceSwitching
    var realtimeCallVoiceError by state.realtimeCallVoiceError

    var translationProviderResponse: RealtimeTranslationProviderResponse?
        get() = state.translationProviderResponse.value
        set(value) {
            state.translationProviderResponse.value = value
        }
    var translationProviderLoading by state.translationProviderLoading
    var translationProviderSwitching by state.translationProviderSwitching
    var translationProviderError by state.translationProviderError

    val realtimeProviderLoadState: AssistantInitializationLoadState
        get() = assistantProviderLoadState(
            loading = realtimeProviderLoading,
            hasResponse = realtimeProviderResponse != null,
            error = realtimeProviderError
        )

    val translationProviderLoadState: AssistantInitializationLoadState
        get() = assistantProviderLoadState(
            loading = translationProviderLoading,
            hasResponse = translationProviderResponse != null,
            error = translationProviderError
        )

    val activeRealtimeProviderSummary: String
        get() {
            val response = realtimeProviderResponse
            val activeProvider = response?.providers?.firstOrNull { it.active }
            val provider = activeProvider?.provider ?: response?.activeProvider
            val displayName = activeProvider?.displayName ?: response?.activeProviderDisplayName
            return AssistantCallModelDisplayNames.resolve(provider, displayName).orEmpty()
        }

    val activeRealtimeCallVoiceSummary: String
        get() {
            val response = realtimeCallVoiceResponse
            if (response?.selectionMode.equals("CLONE", ignoreCase = true)) {
                return currentAppText("我的克隆音色", "My Cloned Voice")
            }
            val activeVoice = response?.voices?.firstOrNull { it.selected }
            val voiceId = activeVoice?.voice ?: response?.activeVoice.orEmpty()
            val displayName = activeVoice?.displayName
                ?: response?.activeVoiceDisplayName
                ?: voiceId
            return realtimeCallVoiceDisplayName(voiceId, displayName)
        }

    val activeTranslationProviderSummary: String
        get() {
            val response = translationProviderResponse
            val activeProvider = response?.providers?.firstOrNull { it.active }
            val provider = activeProvider?.provider ?: response?.activeProvider
            val displayName = activeProvider?.displayName ?: response?.activeProviderDisplayName
            return normalizeTranslationProviderDisplayName(provider, displayName)
        }

    fun refreshRealtimeCallProvider(force: Boolean = false) {
        if (realtimeProviderLoading && !force) {
            logSettings("CALL_PROVIDER_REFRESH_SKIPPED", result = "skipped", reason = "already_loading")
            return
        }
        realtimeProviderLoading = true
        realtimeProviderError = null
        deps.scope.launch {
            logSettings("CALL_PROVIDER_REFRESH_STARTED")
            runCatching {
                deps.taskRepository.getRealtimeCallProviderSettings()
            }.onSuccess { response ->
                realtimeProviderResponse = response
                logSettings("CALL_PROVIDER_REFRESH_COMPLETED", provider = response.activeProvider, result = "success")
            }.onFailure { throwable ->
                realtimeProviderError = throwable.message ?: currentAppText(
                    "通话模型状态加载失败",
                    "Failed to load call model status"
                )
                logSettings("CALL_PROVIDER_REFRESH_FAILED", result = "failed", throwable = throwable)
            }
            realtimeProviderLoading = false
        }
    }

    fun refreshRealtimeCallVoice(force: Boolean = false) {
        if (realtimeCallVoiceLoading && !force) {
            logSettings("CALL_VOICE_REFRESH_SKIPPED", result = "skipped", reason = "already_loading")
            return
        }
        deps.scope.launch {
            logSettings("CALL_VOICE_REFRESH_STARTED")
            realtimeCallVoiceLoading = true
            realtimeCallVoiceError = null
            runCatching {
                deps.taskRepository.getRealtimeCallVoiceSettings()
            }.onSuccess { response ->
                realtimeCallVoiceResponse = response
                logSettings("CALL_VOICE_REFRESH_COMPLETED", provider = response.activeVoice, result = "success")
            }.onFailure { throwable ->
                realtimeCallVoiceError = throwable.message ?: currentAppText(
                    "AI通话音色加载失败",
                    "Failed to load AI call voices"
                )
                logSettings("CALL_VOICE_REFRESH_FAILED", result = "failed", throwable = throwable)
            }
            realtimeCallVoiceLoading = false
        }
    }

    fun refreshTranslationProvider(force: Boolean = false) {
        if (translationProviderLoading && !force) {
            logSettings("TRANSLATION_PROVIDER_REFRESH_SKIPPED", result = "skipped", reason = "already_loading")
            return
        }
        translationProviderLoading = true
        translationProviderError = null
        deps.scope.launch {
            logSettings("TRANSLATION_PROVIDER_REFRESH_STARTED")
            runCatching {
                deps.taskRepository.getRealtimeTranslationProviderSettings()
            }.onSuccess { response ->
                translationProviderResponse = response
                logSettings("TRANSLATION_PROVIDER_REFRESH_COMPLETED", provider = response.activeProvider, result = "success")
            }.onFailure { throwable ->
                translationProviderError = throwable.message ?: currentAppText(
                    "实时翻译模型状态加载失败",
                    "Failed to load live translation model status"
                )
                logSettings("TRANSLATION_PROVIDER_REFRESH_FAILED", result = "failed", throwable = throwable)
            }
            translationProviderLoading = false
        }
    }

    fun switchRealtimeCallProvider(provider: String) {
        if (realtimeProviderSwitching) {
            logSettings("CALL_PROVIDER_SWITCH_SKIPPED", provider, result = "skipped", reason = "already_switching")
            return
        }
        deps.scope.launch {
            logSettings("CALL_PROVIDER_SWITCH_STARTED", provider)
            realtimeProviderSwitching = true
            realtimeProviderError = null
            runCatching {
                deps.taskRepository.updateRealtimeCallProviderSettings(provider)
            }.onSuccess { response ->
                realtimeProviderResponse = response
                callbacks.onRealtimeProviderChanged()
                logSettings("CALL_PROVIDER_SWITCH_COMPLETED", response.activeProvider, result = "success")
                Toast.makeText(
                    deps.context,
                    currentAppText(
                        "通话模型已切换为 ${response.activeProviderDisplayName.trim()}",
                        "Call model switched to ${response.activeProviderDisplayName.trim()}"
                    ),
                    Toast.LENGTH_SHORT
                ).show()
            }.onFailure { throwable ->
                realtimeProviderError = throwable.message ?: currentAppText(
                    "通话模型切换失败",
                    "Failed to switch call model"
                )
                logSettings("CALL_PROVIDER_SWITCH_FAILED", provider, result = "failed", throwable = throwable)
            }
            if (!realtimeProviderError.isNullOrBlank()) {
                Toast.makeText(
                    deps.context,
                    currentAppText(
                        "通话模型切换失败，请检查网络或本地服务连接",
                        "Failed to switch call model. Check your network or local service connection."
                    ),
                    Toast.LENGTH_SHORT
                ).show()
            }
            realtimeProviderSwitching = false
        }
    }

    fun switchRealtimeCallVoice(voice: String) {
        switchRealtimeCallVoiceSelection(voice, "AI")
    }

    fun switchRealtimeCallVoiceSelection(voice: String?, selectionMode: String) {
        if (realtimeCallVoiceSwitching) {
            logSettings(
                "CALL_VOICE_SWITCH_SKIPPED",
                selectionMode,
                result = "skipped",
                reason = "already_switching"
            )
            return
        }
        deps.scope.launch {
            logSettings("CALL_VOICE_SWITCH_STARTED", selectionMode)
            realtimeCallVoiceSwitching = true
            realtimeCallVoiceError = null
            runCatching {
                deps.taskRepository.updateRealtimeCallVoiceSettings(voice, selectionMode)
            }.onSuccess { response ->
                realtimeCallVoiceResponse = response
                callbacks.onRealtimeCallVoiceChanged()
                logSettings("CALL_VOICE_SWITCH_COMPLETED", response.selectionMode, result = "success")
                Toast.makeText(
                    deps.context,
                    if (response.selectionMode.equals("CLONE", ignoreCase = true)) {
                        currentAppText("已切换为我的克隆音色", "Switched to my cloned voice")
                    } else {
                        currentAppText(
                            "AI通话音色已切换为 ${response.activeVoiceDisplayName.ifBlank { response.activeVoice }}",
                            "AI call voice switched to ${response.activeVoiceDisplayName.ifBlank { response.activeVoice }}"
                        )
                    },
                    Toast.LENGTH_SHORT
                ).show()
            }.onFailure { throwable ->
                realtimeCallVoiceError = throwable.message ?: currentAppText(
                    "AI通话音色切换失败",
                    "Failed to switch AI call voice"
                )
                logSettings("CALL_VOICE_SWITCH_FAILED", selectionMode, result = "failed", throwable = throwable)
            }
            realtimeCallVoiceSwitching = false
        }
    }

    fun switchTranslationProvider(provider: String) {
        if (translationProviderSwitching) {
            logSettings("TRANSLATION_PROVIDER_SWITCH_SKIPPED", provider, result = "skipped", reason = "already_switching")
            return
        }
        deps.scope.launch {
            logSettings("TRANSLATION_PROVIDER_SWITCH_STARTED", provider)
            translationProviderSwitching = true
            translationProviderError = null
            runCatching {
                deps.taskRepository.updateRealtimeTranslationProviderSettings(provider)
            }.onSuccess { response ->
                translationProviderResponse = response
                logSettings("TRANSLATION_PROVIDER_SWITCH_COMPLETED", response.activeProvider, result = "success")
                Toast.makeText(
                    deps.context,
                    currentAppText(
                        "翻译通话模型已切换为 ${response.activeProviderDisplayName}",
                        "Translation call model switched to ${response.activeProviderDisplayName}"
                    ),
                    Toast.LENGTH_SHORT
                ).show()
            }.onFailure { throwable ->
                translationProviderError = throwable.message ?: currentAppText(
                    "翻译通话模型切换失败",
                    "Failed to switch translation call model"
                )
                logSettings("TRANSLATION_PROVIDER_SWITCH_FAILED", provider, result = "failed", throwable = throwable)
            }
            if (!translationProviderError.isNullOrBlank()) {
                Toast.makeText(
                    deps.context,
                    currentAppText(
                        "同声传译模型切换失败，请检查网络或本地服务连接",
                        "Failed to switch interpretation model. Check your network or local service connection."
                    ),
                    Toast.LENGTH_SHORT
                ).show()
            }
            translationProviderSwitching = false
        }
    }

    private fun logSettings(
        eventType: String,
        provider: String? = null,
        result: String? = null,
        reason: String? = null,
        throwable: Throwable? = null
    ) {
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.SETTINGS,
            eventType = eventType,
            provider = provider,
            result = result,
            reason = reason
        )
        if (throwable == null) RuntimeStateLogger.info(event) else RuntimeStateLogger.warn(event, throwable)
    }
}

@Composable
internal fun rememberAssistantProviderRuntimeController(
    deps: AssistantProviderRuntimeDeps,
    callbacks: AssistantProviderRuntimeCallbacks
): AssistantProviderRuntimeController {
    val state = AssistantProviderRuntimeState(
        realtimeProviderResponse = remember { mutableStateOf<RealtimeCallProviderResponse?>(null) },
        realtimeProviderLoading = remember { mutableStateOf(false) },
        realtimeProviderSwitching = remember { mutableStateOf(false) },
        realtimeProviderError = rememberSaveable { mutableStateOf<String?>(null) },
        realtimeCallVoiceResponse = remember { mutableStateOf<RealtimeCallVoiceResponse?>(null) },
        realtimeCallVoiceLoading = remember { mutableStateOf(false) },
        realtimeCallVoiceSwitching = remember { mutableStateOf(false) },
        realtimeCallVoiceError = rememberSaveable { mutableStateOf<String?>(null) },
        translationProviderResponse = remember { mutableStateOf<RealtimeTranslationProviderResponse?>(null) },
        translationProviderLoading = remember { mutableStateOf(false) },
        translationProviderSwitching = remember { mutableStateOf(false) },
        translationProviderError = rememberSaveable { mutableStateOf<String?>(null) }
    )
    val controller = remember(deps.context, deps.taskRepository, deps.scope) {
        AssistantProviderRuntimeController(deps, state)
    }
    controller.callbacks = callbacks
    return controller
}
