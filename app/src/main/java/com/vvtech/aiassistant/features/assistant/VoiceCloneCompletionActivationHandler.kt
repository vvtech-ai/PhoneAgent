package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import java.util.Locale

internal class VoiceCloneCompletionActivationHandler(
    private val state: AssistantVoiceCloneRuntimeState,
    private val activateCompletedClone: (
        Boolean,
        (Result<VoiceCloneStatusResponse>) -> Unit
    ) -> Unit
) {
    fun activate(
        improvementConsent: Boolean,
        onMessage: (String) -> Unit,
        onActivated: () -> Unit
    ) {
        if (state.status.value?.status?.uppercase(Locale.ROOT) != "READY") {
            onMessage("声音正在生成中，完成后可在语音设置中启用")
            return
        }
        if (state.actionLoading.value) return
        state.actionLoading.value = true
        state.error.value = null
        activateCompletedClone(improvementConsent) { result ->
            result.onSuccess { nextStatus ->
                val enrollmentAvailable =
                    nextStatus.enrollmentAvailable ||
                        state.status.value?.enrollmentAvailable == true
                state.status.value = nextStatus.copy(
                    enrollmentAvailable = enrollmentAvailable
                )
                onMessage("已切换为我的克隆音色")
                onActivated()
            }.onFailure { throwable ->
                state.error.value = throwable.message ?: "启用克隆音色失败"
            }
            state.actionLoading.value = false
        }
    }
}
