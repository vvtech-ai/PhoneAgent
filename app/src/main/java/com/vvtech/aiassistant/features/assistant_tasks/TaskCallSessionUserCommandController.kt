package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class TaskCallSessionUserCommandControllerDeps(
    val scope: CoroutineScope,
    val userIdProvider: () -> String,
    val stateProvider: () -> Index9AssistantUiState,
    val updateState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    val commandUseCase: TaskCallSessionCommandUseCase,
    val stopAssistantSpeech: () -> Unit,
    val stopVoiceInteraction: () -> Unit,
    val prepareHumanTakeoverRequest: () -> Unit,
    val clearTakeoverProtectWindow: () -> Unit,
    val stopTakeoverAudioSocket: () -> Unit,
    val stopCallSessionPolling: () -> Unit,
    val applyCallSessionStatus: (CallSessionStatusResponse, Boolean) -> Unit,
    val dismissAiCallPage: () -> Unit,
    val appendCallNote: (String) -> Unit
)

internal class TaskCallSessionUserCommandController(
    private val deps: TaskCallSessionUserCommandControllerDeps
) {
    fun requestHumanTakeover() {
        val state = deps.stateProvider()
        if (!state.showAiCallPage || state.handoffInFlight) return
        deps.scope.launch {
            deps.stopAssistantSpeech()
            deps.stopVoiceInteraction()
            deps.prepareHumanTakeoverRequest()
            deps.updateState {
                it.copy(
                    handoffInFlight = true,
                    callPageData = it.callPageData.copy(status = "正在请求人工接管...")
                )
            }
            runCatching {
                deps.commandUseCase.requestHumanTakeover(
                    userId = deps.userIdProvider(),
                    taskId = state.taskId,
                    callId = state.currentCallId
                )
            }.onSuccess { response ->
                deps.applyCallSessionStatus(response, true)
            }.onFailure { throwable ->
                deps.updateState {
                    it.copy(
                        handoffInFlight = false,
                        callPageData = it.callPageData.copy(
                            status = throwable.message ?: "人工接管请求失败"
                        )
                    )
                }
                deps.appendCallNote(throwable.message ?: "人工接管请求失败，请稍后再试")
            }
        }
    }

    fun releaseToAi() {
        val state = deps.stateProvider()
        if (!state.showAiCallPage || state.handoffInFlight) return
        deps.scope.launch {
            deps.clearTakeoverProtectWindow()
            deps.updateState {
                it.copy(
                    handoffInFlight = true,
                    callPageData = it.callPageData.copy(status = "正在切回 AI 代打...")
                )
            }
            runCatching {
                deps.commandUseCase.releaseToAi(
                    userId = deps.userIdProvider(),
                    taskId = state.taskId,
                    callId = state.currentCallId
                )
            }.onSuccess { response ->
                deps.stopTakeoverAudioSocket()
                deps.applyCallSessionStatus(response, true)
            }.onFailure { throwable ->
                deps.updateState {
                    it.copy(
                        handoffInFlight = false,
                        callPageData = it.callPageData.copy(
                            status = throwable.message ?: "切回 AI 失败"
                        )
                    )
                }
                deps.appendCallNote(throwable.message ?: "切回 AI 失败，请稍后再试")
            }
        }
    }

    fun hangUpCall(onFinished: (() -> Unit)? = null) {
        val state = deps.stateProvider()
        if (!state.showAiCallPage || state.handoffInFlight) return
        deps.scope.launch {
            deps.updateState {
                it.copy(
                    handoffInFlight = true,
                    callPageData = it.callPageData.copy(status = "正在挂断通话...")
                )
            }
            runCatching {
                deps.commandUseCase.hangUp(
                    userId = deps.userIdProvider(),
                    taskId = state.taskId,
                    callId = state.currentCallId
                )
            }.onSuccess { response ->
                deps.stopTakeoverAudioSocket()
                deps.stopCallSessionPolling()
                deps.applyCallSessionStatus(response, true)
                deps.dismissAiCallPage()
                onFinished?.invoke()
            }.onFailure { throwable ->
                deps.updateState {
                    it.copy(
                        handoffInFlight = false,
                        callPageData = it.callPageData.copy(
                            status = throwable.message ?: "挂断失败"
                        )
                    )
                }
                deps.appendCallNote(throwable.message ?: "挂断失败，请稍后再试")
            }
        }
    }
}
