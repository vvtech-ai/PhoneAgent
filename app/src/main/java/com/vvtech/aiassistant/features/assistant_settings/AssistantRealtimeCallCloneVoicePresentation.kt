package com.vvtech.aiassistant.features.assistant_settings

import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import com.vvtech.aiassistant.features.assistant_i18n.appText
import java.util.Locale

internal data class RealtimeCallCloneVoicePresentation(
    val statusText: String,
    val actionText: String
)

internal fun realtimeCallCloneVoicePresentation(
    status: String?,
    selected: Boolean,
    appLanguage: AppLanguage = AppLanguage.SimplifiedChinese
): RealtimeCallCloneVoicePresentation = when (status?.trim()?.uppercase(Locale.ROOT).orEmpty()) {
    "READY" -> RealtimeCallCloneVoicePresentation(
        statusText = if (selected) {
            "当前选择".appText(appLanguage, "Current")
        } else {
            "选择".appText(appLanguage, "Select")
        },
        actionText = "重新录制".appText(appLanguage, "Record Again")
    )
    "EXPIRED" -> RealtimeCallCloneVoicePresentation(
        "已过期".appText(appLanguage, "Expired"),
        "重新录制".appText(appLanguage, "Record Again")
    )
    "PROCESSING", "INIT", "PENDING" ->
        RealtimeCallCloneVoicePresentation(
            "生成中".appText(appLanguage, "Generating"),
            "重新录制".appText(appLanguage, "Record Again")
        )
    "FAILED", "ERROR", "FAIL" ->
        RealtimeCallCloneVoicePresentation(
            "生成失败".appText(appLanguage, "Generation Failed"),
            "重新录制".appText(appLanguage, "Record Again")
        )
    else -> RealtimeCallCloneVoicePresentation(
        "未克隆".appText(appLanguage, "Not Created"),
        "声音克隆".appText(appLanguage, "Voice Cloning")
    )
}

internal fun realtimeCallCloneVoiceDetail(
    status: String?,
    hasClone: Boolean,
    lastError: String?,
    appLanguage: AppLanguage = AppLanguage.SimplifiedChinese
): String {
    val normalizedStatus = status?.trim()?.uppercase(Locale.ROOT).orEmpty()
    return when {
        normalizedStatus == "EXPIRED" ->
            lastError?.ifBlank {
                "旧版本克隆音色已过期，请重新录制。".appText(
                    appLanguage,
                    "The old cloned voice has expired. Please record it again."
                )
            } ?: "旧版本克隆音色已过期，请重新录制。".appText(
                appLanguage,
                "The old cloned voice has expired. Please record it again."
            )
        !hasClone -> "当前模型暂无可用的克隆音色，完成声音克隆后即可使用".appText(
            appLanguage,
            "No cloned voice is available for this model yet. Complete Voice Cloning to use one."
        )
        normalizedStatus == "READY" -> "当前模型已有可用的克隆音色".appText(
            appLanguage,
            "This model has a cloned voice ready to use."
        )
        else -> "克隆音色正在生成中，完成后可以切换使用".appText(
            appLanguage,
            "The cloned voice is being generated. You can switch to it when it is ready."
        )
    }
}
