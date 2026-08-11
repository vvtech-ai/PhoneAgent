package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneEnrollmentCollection
import com.vvtech.aiassistant.model.VoiceCloneScriptItem

internal fun AssistantVoiceCloneRuntimeState.applyCollection(
    collection: VoiceCloneEnrollmentCollection
) {
    scripts.value = listOf(
        VoiceCloneScriptItem(
            scriptId = collection.scriptId,
            text = collection.scriptText,
            minDurationSeconds = collection.minDurationSeconds,
            title = "动态短句",
            recordingTips = "请完整朗读屏幕短句",
            targetDurationSeconds = collection.targetDurationSeconds
        )
    )
    scriptsVersion.value = "voice-clone-v5"
    samples.value = emptyMap()
    currentScriptIndex.value = 0
}
