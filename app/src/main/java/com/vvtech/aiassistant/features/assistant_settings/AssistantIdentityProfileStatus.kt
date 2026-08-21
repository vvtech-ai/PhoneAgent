package com.vvtech.aiassistant.features.assistant_settings

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal enum class AssistantIdentityProfileStatus(
    private val chineseLabel: String,
    private val englishLabel: String,
    private val chineseHint: String,
    private val englishHint: String
) {
    Empty(
        chineseLabel = "未填写",
        englishLabel = "Not Added",
        chineseHint = "尚未填写身份资料，完善后 AI 通话可使用这份介绍。",
        englishHint = "Identity details are not added yet. AI calls can use this intro after you complete it."
    ),
    Filled(
        chineseLabel = "已填写",
        englishLabel = "Added",
        chineseHint = "身份资料已保存，完成声音克隆认证后会显示为已认证。",
        englishHint = "Identity details are saved. After voice-clone verification, the profile will show as verified."
    ),
    Verified(
        chineseLabel = "已认证",
        englishLabel = "Verified",
        chineseHint = "身份资料已通过服务端认证流程，可用于 AI 通话。",
        englishHint = "Identity details have passed server verification and can be used for AI calls."
    );

    val label: String
        get() = currentAppText(chineseLabel, englishLabel)

    val hint: String
        get() = currentAppText(chineseHint, englishHint)

    companion object {
        fun fromServer(raw: String?): AssistantIdentityProfileStatus = when (raw?.trim()?.uppercase()) {
            "FILLED" -> Filled
            "VERIFIED" -> Verified
            else -> Empty
        }
    }
}
