package com.vvtech.aiassistant.features.assistant_home

import android.content.Context
import com.vvtech.aiassistant.core.model.StartRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.StopRealtimeSessionRequest
import com.vvtech.aiassistant.domain.usecase.StartRealtimeSessionUseCase
import com.vvtech.aiassistant.domain.usecase.StopRealtimeSessionUseCase
import com.vvtech.aiassistant.voice.VoiceRuntimeConfig
import com.vvtech.aiassistant.voice.VoiceRuntimeEvent
import com.vvtech.aiassistant.voice.VolcRtcVoiceClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal data class AssistantHomeVoiceRuntimeDeps(
    val uiState: MutableStateFlow<AssistantHomeUiState>,
    val scope: CoroutineScope,
    val startRealtimeSession: StartRealtimeSessionUseCase,
    val stopRealtimeSession: StopRealtimeSessionUseCase,
    val userIdProvider: () -> String,
    val clientFactory: (Context) -> VolcRtcVoiceClient = ::VolcRtcVoiceClient
)

internal class AssistantHomeVoiceRuntimeController(
    private val deps: AssistantHomeVoiceRuntimeDeps
) {
    private var voiceClient: VolcRtcVoiceClient? = null

    fun onAudioPermissionDenied() {
        deps.uiState.update {
            it.copy(
                voiceConnecting = false,
                voiceActive = false,
                voiceError = "没有拿到麦克风权限，暂时还不能进入实时语音。",
                voiceHint = "给我麦克风权限后，就能直接语音对话。"
            )
        }
    }

    fun toggle(
        context: Context,
        hasAudioPermission: Boolean,
        requestAudioPermission: () -> Unit
    ) {
        if (deps.uiState.value.voiceActive || deps.uiState.value.voiceConnecting) {
            stopVoiceSession()
            return
        }
        if (!hasAudioPermission) {
            requestAudioPermission()
            return
        }
        startVoiceSession(context.applicationContext)
    }

    fun release() {
        voiceClient?.release()
        voiceClient = null
    }

    private fun startVoiceSession(context: Context) {
        deps.uiState.update {
            it.copy(
                voiceConnecting = true,
                voiceActive = false,
                voiceError = null,
                voiceHint = "正在准备实时语音..."
            )
        }
        deps.scope.launch {
            runCatching {
                deps.startRealtimeSession(
                    StartRealtimeSessionRequest(
                        userId = deps.userIdProvider(),
                        taskId = deps.uiState.value.taskId,
                        userContext = deps.uiState.value.userContext
                    )
                )
            }.onSuccess { response ->
                val rtc = response.rtc
                if (!response.ready || rtc == null) {
                    deps.uiState.update {
                        it.copy(
                            voiceConnecting = false,
                            voiceActive = false,
                            voiceSessionId = response.sessionId,
                            voiceError = response.statusMessage.ifBlank { "实时语音暂时不可用" },
                            voiceHint = response.statusMessage.ifBlank { "先继续打字也可以" }
                        )
                    }
                    return@onSuccess
                }

                val client = voiceClient ?: deps.clientFactory(context).also { voiceClient = it }
                client.start(
                    VoiceRuntimeConfig(
                        appId = rtc.appId,
                        roomId = rtc.roomId,
                        userId = rtc.userId,
                        token = rtc.token
                    ),
                    ::handleVoiceEvent
                )
                deps.uiState.update {
                    it.copy(
                        voiceConnecting = true,
                        voiceActive = false,
                        voiceSessionId = response.sessionId,
                        voiceError = null,
                        voiceHint = when {
                            response.agentReady -> response.statusMessage.ifBlank { "正在连接实时语音..." }
                            else -> response.statusMessage.ifBlank { "RTC 已就绪，正在先把语音房间连上..." }
                        }
                    )
                }
            }.onFailure { throwable ->
                deps.uiState.update {
                    it.copy(
                        voiceConnecting = false,
                        voiceActive = false,
                        voiceError = throwable.message ?: "实时语音启动失败",
                        voiceHint = "先用文字告诉我也可以"
                    )
                }
            }
        }
    }

    private fun stopVoiceSession() {
        voiceClient?.stop()
        val sessionId = deps.uiState.value.voiceSessionId
        deps.uiState.update {
            it.copy(
                voiceConnecting = false,
                voiceActive = false,
                voiceHint = "实时语音已结束",
                voiceError = null
            )
        }
        if (!sessionId.isNullOrBlank()) {
            deps.scope.launch {
                runCatching {
                    deps.stopRealtimeSession(
                        StopRealtimeSessionRequest(
                            userId = deps.userIdProvider(),
                            sessionId = sessionId,
                            taskId = deps.uiState.value.taskId
                        )
                    )
                }
            }
        }
    }

    private fun handleVoiceEvent(event: VoiceRuntimeEvent) {
        when (event) {
            is VoiceRuntimeEvent.Connecting -> {
                deps.uiState.update {
                    it.copy(
                        voiceConnecting = true,
                        voiceActive = false,
                        voiceError = null,
                        voiceHint = event.message
                    )
                }
            }

            is VoiceRuntimeEvent.Connected -> {
                deps.uiState.update {
                    it.copy(
                        voiceConnecting = false,
                        voiceActive = true,
                        voiceError = null,
                        voiceHint = event.message
                    )
                }
            }

            is VoiceRuntimeEvent.Status -> {
                deps.uiState.update { it.copy(voiceHint = event.message) }
            }

            is VoiceRuntimeEvent.Transcript -> Unit

            is VoiceRuntimeEvent.Error -> {
                deps.uiState.update {
                    it.copy(
                        voiceConnecting = false,
                        voiceActive = false,
                        voiceError = event.message,
                        voiceHint = "先用文字继续也可以"
                    )
                }
            }

            VoiceRuntimeEvent.Stopped -> {
                deps.uiState.update {
                    it.copy(
                        voiceConnecting = false,
                        voiceActive = false,
                        voiceError = null,
                        voiceHint = "实时语音已结束"
                    )
                }
            }
        }
    }
}
