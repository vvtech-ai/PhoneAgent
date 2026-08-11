package com.vvtech.aiassistant.features.assistant_settings

import java.util.Locale

internal data class RealtimeCallCloneVoicePresentation(
    val statusText: String,
    val actionText: String
)

internal fun realtimeCallCloneVoicePresentation(
    status: String?,
    selected: Boolean
): RealtimeCallCloneVoicePresentation = when (status?.trim()?.uppercase(Locale.ROOT).orEmpty()) {
    "READY" -> RealtimeCallCloneVoicePresentation(
        statusText = if (selected) "当前选择" else "选择",
        actionText = "重新录制"
    )
    "EXPIRED" -> RealtimeCallCloneVoicePresentation("已过期", "重新录制")
    "PROCESSING", "INIT", "PENDING" ->
        RealtimeCallCloneVoicePresentation("生成中", "重新录制")
    "FAILED", "ERROR", "FAIL" ->
        RealtimeCallCloneVoicePresentation("生成失败", "重新录制")
    else -> RealtimeCallCloneVoicePresentation("未克隆", "声音克隆")
}

internal fun realtimeCallCloneVoiceDetail(
    status: String?,
    hasClone: Boolean,
    lastError: String?
): String {
    val normalizedStatus = status?.trim()?.uppercase(Locale.ROOT).orEmpty()
    return when {
        normalizedStatus == "EXPIRED" ->
            lastError?.ifBlank { "旧版本克隆音色已过期，请重新录制。" }
                ?: "旧版本克隆音色已过期，请重新录制。"
        !hasClone -> "当前模型暂无可用的克隆音色，完成声音克隆后即可使用"
        normalizedStatus == "READY" -> "当前模型已有可用的克隆音色"
        else -> "克隆音色正在生成中，完成后可以切换使用"
    }
}
