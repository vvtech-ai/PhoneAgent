package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_voice_clone.VoiceCloneAvailabilityPolicy
import com.vvtech.aiassistant.features.assistant_voice_clone.logVoiceCloneRuntime
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class AssistantVoiceCloneFlowOpenHandler(
    private val scope: CoroutineScope,
    private val loadStatus: suspend () -> VoiceCloneStatusResponse,
    private val state: AssistantVoiceCloneRuntimeState
) {
    fun open(
        resetRecording: Boolean,
        onAvailable: (Boolean) -> Unit,
        onMessage: (String) -> Unit
    ) {
        val currentStatus = state.status.value
        if (currentStatus != null) {
            if (VoiceCloneAvailabilityPolicy.canEnroll(currentStatus)) {
                onAvailable(resetRecording)
            } else {
                onMessage(
                    VoiceCloneAvailabilityPolicy.enrollmentUnavailableMessage(currentStatus)
                )
            }
            return
        }
        if (state.loading.value) {
            onMessage("身份认证凭证正在恢复，请稍候")
            return
        }

        scope.launch {
            logVoiceCloneRuntime(
                "VOICE_CLONE_ENTRY_RECOVERY_STARTED",
                reason = "status_missing"
            )
            state.loading.value = true
            state.error.value = null
            runCatching {
                loadStatus()
            }.onSuccess { recoveredStatus ->
                state.status.value = recoveredStatus
                state.currentScriptIndex.value = 0
                logVoiceCloneRuntime(
                    "VOICE_CLONE_ENTRY_RECOVERY_COMPLETED",
                    result = "success",
                    statusValue = recoveredStatus.status
                )
                if (VoiceCloneAvailabilityPolicy.canEnroll(recoveredStatus)) {
                    onAvailable(resetRecording)
                } else {
                    onMessage(
                        VoiceCloneAvailabilityPolicy.enrollmentUnavailableMessage(
                            recoveredStatus
                        )
                    )
                }
            }.onFailure { throwable ->
                state.error.value = throwable.message ?: "身份认证凭证恢复失败"
                logVoiceCloneRuntime(
                    "VOICE_CLONE_ENTRY_RECOVERY_FAILED",
                    result = "failed",
                    reason = "request_failed",
                    throwable = throwable
                )
                onMessage("身份认证凭证恢复未成功，请点击身份认证重试")
            }
            state.loading.value = false
        }
    }
}
