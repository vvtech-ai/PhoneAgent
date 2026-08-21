package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
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
            onMessage(currentAppText(
                "声音正在生成中，完成后可在语音设置中启用",
                "Your voice is still being generated. You can enable it in voice settings when it is ready."
            ))
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
                onMessage(currentAppText("已切换为我的克隆音色", "Switched to my cloned voice"))
                onActivated()
            }.onFailure { throwable ->
                state.error.value = throwable.message ?: currentAppText(
                    "启用克隆音色失败",
                    "Failed to enable cloned voice"
                )
            }
            state.actionLoading.value = false
        }
    }
}
