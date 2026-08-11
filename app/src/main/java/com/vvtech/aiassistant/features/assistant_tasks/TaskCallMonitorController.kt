package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallMonitorTokenRequest
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRoute
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRouteState
import com.vvtech.aiassistant.features.assistant.CallMonitorPlaybackState
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_audio.CallMonitorAudioSocketClient
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal data class TaskCallMonitorControllerDeps(
    val scope: CoroutineScope,
    val repository: AssistantRepository,
    val userIdProvider: () -> String,
    val stateProvider: () -> Index9AssistantUiState,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val socketClient: CallMonitorAudioSocketClient
)

internal class TaskCallMonitorController(
    private val deps: TaskCallMonitorControllerDeps
) {
    private var reconnectJob: Job? = null
    private var reconnectAttempts = 0

    fun toggle() {
        val state = deps.stateProvider()
        log(
            event = "toggle_requested",
            detail = "stateBefore=${state.callMonitorState}"
        )
        when (state.callMonitorState) {
            CallMonitorPlaybackState.Off,
            CallMonitorPlaybackState.Failed -> {
                reconnectAttempts = 0
                connect(state, CallMonitorPlaybackState.Connecting)
            }

            CallMonitorPlaybackState.Playing -> {
                deps.socketClient.setPlaybackEnabled(false)
                update(CallMonitorPlaybackState.Muted)
            }

            CallMonitorPlaybackState.Muted -> {
                deps.socketClient.setPlaybackEnabled(true)
                update(CallMonitorPlaybackState.Playing)
            }

            CallMonitorPlaybackState.Connecting,
            CallMonitorPlaybackState.Reconnecting -> Unit
        }
    }

    fun selectAudioRoute(route: CallMonitorAudioRoute) {
        val state = deps.stateProvider()
        if (state.callMonitorState != CallMonitorPlaybackState.Playing) {
            log(
                event = "route_ignored",
                detail = "route=$route state=${state.callMonitorState}"
            )
            return
        }
        log(
            event = "route_requested",
            detail = "from=${state.callMonitorAudioRouteState.selected} to=$route"
        )
        deps.socketClient.selectAudioRoute(route)
    }

    fun stop() {
        reconnectJob?.cancel()
        reconnectJob = null
        reconnectAttempts = 0
        deps.socketClient.stop()
        deps.updateState {
            it.copy(
                callMonitorState = CallMonitorPlaybackState.Off,
                callMonitorAudioRouteState = CallMonitorAudioRouteState()
            )
        }
        log(event = "stopped", detail = "routeReset=Earpiece")
    }

    private fun connect(
        state: Index9AssistantUiState,
        pendingState: CallMonitorPlaybackState
    ) {
        val callId = state.currentCallId?.trim().orEmpty()
        if (callId.isBlank()) {
            update(CallMonitorPlaybackState.Failed)
            return
        }
        update(pendingState)
        deps.scope.launch {
            runCatching {
                deps.repository.createCallMonitorToken(
                    CallMonitorTokenRequest(
                        userId = deps.userIdProvider(),
                        taskId = state.taskId,
                        callId = callId
                    )
                )
            }.onSuccess { response ->
                val latest = deps.stateProvider()
                if (latest.currentCallId != callId || !latest.showAiCallPage) {
                    update(CallMonitorPlaybackState.Off)
                    return@onSuccess
                }
                deps.socketClient.start(
                    ticket = response.ticket,
                    initialRoute = latest.callMonitorAudioRouteState.selected,
                    onEvent = ::handleEvent
                )
            }.onFailure {
                scheduleReconnect()
            }
        }
    }

    private fun handleEvent(event: CallMonitorAudioSocketClient.Event) {
        when (event) {
            CallMonitorAudioSocketClient.Event.Connected -> {
                reconnectJob?.cancel()
                reconnectAttempts = 0
                update(CallMonitorPlaybackState.Playing)
            }

            CallMonitorAudioSocketClient.Event.Closed ->
                scheduleReconnect()

            is CallMonitorAudioSocketClient.Event.Error ->
                scheduleReconnect()

            is CallMonitorAudioSocketClient.Event.AudioRouteChanged -> {
                deps.updateState {
                    it.copy(callMonitorAudioRouteState = event.state)
                }
                log(
                    event = "route_changed",
                    detail = "route=${event.state.selected} " +
                        "bluetoothAvailable=${event.state.bluetoothAvailable} " +
                        "reason=${event.reason}"
                )
            }
        }
    }

    private fun scheduleReconnect() {
        val state = deps.stateProvider()
        if (!state.showAiCallPage || state.callUiMode != CallUiMode.Ai ||
            state.currentCallId.isNullOrBlank() || reconnectAttempts >= MaxReconnectAttempts
        ) {
            update(CallMonitorPlaybackState.Failed)
            return
        }
        reconnectAttempts++
        update(CallMonitorPlaybackState.Reconnecting)
        reconnectJob?.cancel()
        reconnectJob = deps.scope.launch {
            delay(ReconnectDelayMillis)
            val latest = deps.stateProvider()
            if (!latest.showAiCallPage || latest.callUiMode != CallUiMode.Ai) {
                return@launch
            }
            connect(latest, CallMonitorPlaybackState.Reconnecting)
        }
    }

    private fun update(state: CallMonitorPlaybackState) {
        val before = deps.stateProvider().callMonitorState
        deps.updateState { it.copy(callMonitorState = state) }
        log(event = "state_changed", detail = "stateBefore=$before stateAfter=$state")
    }

    private fun log(event: String, detail: String) {
        val state = deps.stateProvider()
        AppFileLogger.i(
            "CallMonitor",
            "event=$event taskId=${state.taskId.orEmpty()} " +
                "callId=${state.currentCallId.orEmpty()} $detail"
        )
    }
}

private const val MaxReconnectAttempts = 3
private const val ReconnectDelayMillis = 800L
