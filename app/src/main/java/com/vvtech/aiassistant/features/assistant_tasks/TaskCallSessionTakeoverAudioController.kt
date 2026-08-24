package com.vvtech.aiassistant.features.assistant_tasks

import android.os.SystemClock
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TakeoverAudioSocketClient
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal data class TaskCallSessionTakeoverAudioControllerDeps(
    val scope: CoroutineScope,
    val stateProvider: () -> Index9AssistantUiState,
    val activeCallIdProvider: () -> String?,
    val setActiveCallId: (String?) -> Unit,
    val earliestStartProvider: () -> Long,
    val setEarliestStart: (Long) -> Unit,
    val setProtectUntil: (Long) -> Unit,
    val reconnectJobProvider: () -> Job?,
    val setReconnectJob: (Job?) -> Unit,
    val socketClient: TakeoverAudioSocketClient,
    val appendNote: (String) -> Unit,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit
)

internal class TaskCallSessionTakeoverAudioController(
    private val deps: TaskCallSessionTakeoverAudioControllerDeps,
    private val audioStartDelayMillis: Long,
    private val reconnectDelayMillis: Long
) {
    fun prepareHumanTakeoverRequest() {
        deps.reconnectJobProvider()?.cancel()
        deps.setEarliestStart(SystemClock.elapsedRealtime() + audioStartDelayMillis)
        deps.setProtectUntil(SystemClock.elapsedRealtime() + TakeoverProtectWindowMillis)
    }

    fun clearProtectWindow() {
        deps.setProtectUntil(0L)
    }

    fun setPlaybackEnabled(enabled: Boolean) {
        deps.socketClient.setPlaybackEnabled(enabled)
    }

    fun setCaptureEnabled(enabled: Boolean) {
        deps.socketClient.setCaptureEnabled(enabled)
    }

    fun setSpeakerphoneEnabled(enabled: Boolean) {
        deps.socketClient.setSpeakerphoneEnabled(enabled)
    }

    fun ensure(taskId: String?, callId: String?) {
        val safeCallId = callId?.trim().orEmpty()
        if (safeCallId.isBlank()) {
            return
        }
        if (deps.activeCallIdProvider() == safeCallId) {
            return
        }
        val now = SystemClock.elapsedRealtime()
        val remainingDelay = deps.earliestStartProvider() - now
        if (remainingDelay > 0L) {
            deps.reconnectJobProvider()?.cancel()
            deps.setReconnectJob(
                deps.scope.launch {
                    delay(remainingDelay)
                    val latest = deps.stateProvider()
                    if (!latest.showAiCallPage || latest.currentCallId != safeCallId) {
                        return@launch
                    }
                    deps.appendNote(currentAppText("正在准备人工接管音频...", "Preparing human takeover audio..."))
                    ensure(taskId, safeCallId)
                }
            )
            return
        }
        deps.reconnectJobProvider()?.cancel()
        stop()
        deps.setActiveCallId(safeCallId)
        deps.socketClient.start(taskId, safeCallId, ::handleEvent)
        deps.socketClient.setCaptureEnabled(!deps.stateProvider().humanMicrophoneMuted)
    }

    fun stop() {
        deps.reconnectJobProvider()?.cancel()
        deps.setActiveCallId(null)
        deps.socketClient.release()
    }

    fun handleEvent(event: TakeoverAudioSocketClient.Event) {
        when (event) {
            TakeoverAudioSocketClient.Event.Connected -> {
                deps.reconnectJobProvider()?.cancel()
                deps.setProtectUntil(SystemClock.elapsedRealtime() + TakeoverProtectWindowMillis)
                deps.appendNote(currentAppText(
                    "人工接管语音已接通，可以继续人工通话",
                    "Human takeover audio is connected. You can continue the call."
                ))
                deps.updateState {
                    it.copy(
                        callPageData = it.callPageData.copy(
                            status = currentAppText("人工接管中", "Human Takeover")
                        )
                    )
                }
            }

            is TakeoverAudioSocketClient.Event.Status -> {
                deps.updateState {
                    it.copy(
                        callPageData = it.callPageData.copy(
                            status = event.message.ifBlank { it.callPageData.status }
                        )
                    )
                }
            }

            is TakeoverAudioSocketClient.Event.Error -> {
                deps.setActiveCallId(null)
                deps.appendNote(event.message)
                deps.updateState {
                    it.copy(
                        callPageData = it.callPageData.copy(status = event.message)
                    )
                }
                scheduleReconnect(
                    taskCallSessionTakeoverReconnectDelayMillis(
                        message = event.message,
                        defaultDelayMillis = reconnectDelayMillis
                    )
                )
            }

            TakeoverAudioSocketClient.Event.Closed -> {
                deps.setProtectUntil(0L)
                deps.setActiveCallId(null)
                deps.updateState {
                    it.copy(
                        callPageData = it.callPageData.copy(
                            status = if (it.callUiMode == CallUiMode.Human) {
                                currentAppText("人工接管音频已断开", "Human takeover audio disconnected")
                            } else {
                                it.callPageData.status
                            }
                        )
                    )
                }
                scheduleReconnect(reconnectDelayMillis)
            }
        }
    }

    fun scheduleReconnect(delayMillis: Long = FastTakeoverReconnectDelayMillis) {
        val state = deps.stateProvider()
        if (!state.showAiCallPage || state.callUiMode != CallUiMode.Human) {
            return
        }
        val callId = state.currentCallId?.trim().orEmpty()
        if (callId.isBlank()) {
            return
        }
        deps.reconnectJobProvider()?.cancel()
        deps.setReconnectJob(
            deps.scope.launch {
                delay(delayMillis)
                val latest = deps.stateProvider()
                if (!latest.showAiCallPage || latest.callUiMode != CallUiMode.Human || latest.currentCallId != callId) {
                    return@launch
                }
                deps.appendNote(currentAppText("人工接管音频重连中...", "Reconnecting human takeover audio..."))
                deps.setEarliestStart(SystemClock.elapsedRealtime() + delayMillis)
                deps.setProtectUntil(SystemClock.elapsedRealtime() + TakeoverProtectWindowMillis)
                ensure(latest.taskId, callId)
            }
        )
    }
}

internal fun taskCallSessionTakeoverReconnectDelayMillis(
    message: String,
    defaultDelayMillis: Long
): Long {
    return if (message.contains("麦克风", ignoreCase = false) || message.contains("microphone", ignoreCase = true)) {
        defaultDelayMillis
    } else {
        FastTakeoverReconnectDelayMillis
    }
}

private const val TakeoverProtectWindowMillis = 5_000L
private const val FastTakeoverReconnectDelayMillis = 450L
