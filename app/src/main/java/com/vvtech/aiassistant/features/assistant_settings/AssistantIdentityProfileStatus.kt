package com.vvtech.aiassistant.features.assistant_settings

internal enum class AssistantIdentityProfileStatus(
    val label: String,
    val hint: String
) {
    Empty(
        label = "未填写",
        hint = "尚未填写身份资料，完善后 AI 通话可使用这份介绍。"
    ),
    Filled(
        label = "已填写",
        hint = "身份资料已保存，完成声音克隆认证后会显示为已认证。"
    ),
    Verified(
        label = "已认证",
        hint = "身份资料已通过服务端认证流程，可用于 AI 通话。"
    );

    companion object {
        fun fromServer(raw: String?): AssistantIdentityProfileStatus = when (raw?.trim()?.uppercase()) {
            "FILLED" -> Filled
            "VERIFIED" -> Verified
            else -> Empty
        }
    }
}
