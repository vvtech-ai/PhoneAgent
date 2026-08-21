package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun subtitleRoleLabel(role: String): String = when (role.lowercase()) {
    "caller" -> currentAppText("你说", "You")
    "callee" -> currentAppText("对方说", "Other Party")
    else -> role
}

internal fun localizedTranslationCallMessage(message: String?): String {
    val raw = message?.trim().orEmpty()
    if (raw.isBlank()) {
        return ""
    }
    return when {
        raw.equals("Remote side is ringing. Waiting for answer.", ignoreCase = true) ->
            currentAppText("对方正在响铃，等待接听。", "Remote side is ringing. Waiting for answer.")
        raw.equals("Preparing SIP call and translation streams.", ignoreCase = true) ->
            currentAppText("正在准备 SIP 通话和实时翻译通道。", "Preparing SIP call and translation streams.")
        raw.equals("Translation media bridge connected. Ready for bidirectional translation.", ignoreCase = true) ->
            currentAppText("通话已接通，实时翻译已准备就绪。", "Call connected. Realtime translation is ready.")
        raw.equals("Detected the same language and switched to passthrough.", ignoreCase = true) ->
            currentAppText("已检测到双方使用同一语种，当前为直通模式。", "Detected the same language and switched to passthrough.")
        raw.equals("Translation languages were manually overridden.", ignoreCase = true) ->
            currentAppText("语言设置已更新。", "Language settings updated.")
        raw.equals("Current provider does not support realtime translation calls.", ignoreCase = true) ->
            currentAppText("当前服务暂不支持实时翻译通话。", "Current provider does not support realtime translation calls.")
        raw.equals("User ended the realtime translation call.", ignoreCase = true) ->
            currentAppText("用户已结束实时翻译通话。", "User ended the realtime translation call.")
        raw.equals("No active realtime translation call was found.", ignoreCase = true) ->
            currentAppText("未找到正在进行的实时翻译通话。", "No active realtime translation call was found.")
        raw.equals("Realtime translation session connected.", ignoreCase = true) ->
            currentAppText("实时翻译会话已连接，正在识别语言。", "Realtime translation session connected. Detecting language.")
        raw.equals("Doubao AST translation session connected.", ignoreCase = true) ->
            currentAppText("实时翻译会话已连接，正在识别语言。", "Realtime translation session connected. Detecting language.")
        raw.equals("Realtime translation session is ready.", ignoreCase = true) ->
            currentAppText("实时翻译会话已准备就绪。", "Realtime translation session is ready.")
        raw.equals("Realtime translation is active.", ignoreCase = true) ->
            currentAppText("实时翻译已开启。", "Realtime translation is active.")
        raw.equals("Doubao AST translation session is ready.", ignoreCase = true) ->
            currentAppText("实时翻译会话已准备就绪。", "Realtime translation session is ready.")
        raw.equals("Doubao AST realtime translation is active.", ignoreCase = true) ->
            currentAppText("实时翻译已开启。", "Realtime translation is active.")
        raw.equals("Translated subtitles updated.", ignoreCase = true) ->
            currentAppText("译文字幕已更新。", "Translated subtitles updated.")
        raw.equals("Translation audio channel disconnected. Waiting for reconnection.", ignoreCase = true) ->
            currentAppText("翻译音频通道已断开，正在等待重连。", "Translation audio channel disconnected. Waiting for reconnection.")
        raw.equals("Translation audio channel reconnected. Resuming realtime translation.", ignoreCase = true) ->
            currentAppText("翻译音频通道已恢复，正在继续实时翻译。", "Translation audio channel reconnected. Resuming realtime translation.")
        raw.equals("Translation audio channel did not recover in time. The realtime translation call was ended automatically.", ignoreCase = true) ->
            currentAppText("翻译音频通道长时间未恢复，系统已自动结束实时翻译通话。", "Translation audio channel did not recover in time. The call was ended automatically.")
        raw.startsWith("Failed to start realtime translation session:", ignoreCase = true) ->
            currentAppText("启动实时翻译会话失败：${raw.substringAfter(':').trim()}", "Failed to start realtime translation session: ${raw.substringAfter(':').trim()}")
        raw.startsWith("Failed to launch SIP translation call:", ignoreCase = true) ->
            currentAppText("发起 SIP 实时翻译通话失败：${raw.substringAfter(':').trim()}", "Failed to launch SIP translation call: ${raw.substringAfter(':').trim()}")
        raw.startsWith("Translation call failed before media bridge was ready:", ignoreCase = true) ->
            currentAppText("实时翻译通话失败，媒体通道尚未就绪：${raw.substringAfter(':').trim()}", "Translation call failed before media bridge was ready: ${raw.substringAfter(':').trim()}")
        raw.startsWith("SIP REGISTER rejected:", ignoreCase = true) ->
            currentAppText("SIP 注册被拒绝：${raw.substringAfter(':').trim()}", "SIP REGISTER rejected: ${raw.substringAfter(':').trim()}")
        raw.startsWith("SIP INVITE rejected:", ignoreCase = true) ->
            currentAppText("SIP 呼叫被拒绝：${raw.substringAfter(':').trim()}", "SIP INVITE rejected: ${raw.substringAfter(':').trim()}")
        raw.startsWith("SIP INVITE failed:", ignoreCase = true) ->
            currentAppText("SIP 呼叫失败：${raw.substringAfter(':').trim()}", "SIP INVITE failed: ${raw.substringAfter(':').trim()}")
        raw.equals("Timed out waiting for SIP REGISTER.", ignoreCase = true) ->
            currentAppText("等待 SIP 注册响应超时。", "Timed out waiting for SIP REGISTER.")
        raw.equals("Timed out waiting for SIP INVITE final response.", ignoreCase = true) ->
            currentAppText("等待对方接听超时。", "Timed out waiting for SIP INVITE final response.")
        raw.equals("Timed out waiting for SIP response.", ignoreCase = true) ->
            currentAppText("等待 SIP 响应超时。", "Timed out waiting for SIP response.")
        raw.startsWith("SIP IO error:", ignoreCase = true) ->
            currentAppText("SIP 网络异常：${raw.substringAfter(':').trim()}", "SIP IO error: ${raw.substringAfter(':').trim()}")
        raw.startsWith("Provider error:", ignoreCase = true) ->
            currentAppText("翻译服务异常：${raw.substringAfter(':').trim()}", "Provider error: ${raw.substringAfter(':').trim()}")
        raw.equals("Remote side ended the translation call.", ignoreCase = true) ->
            currentAppText("对方已结束实时翻译通话。", "Remote side ended the translation call.")
        raw.equals("Translation call reached the max conversation window and was closed.", ignoreCase = true) ->
            currentAppText("实时翻译通话已达到最长通话时长，系统已自动结束。", "Translation call reached the max conversation window and was closed.")
        else -> raw
    }
}

internal fun localizedTranslationCallState(state: String?): String {
    return when (state?.trim()?.uppercase().orEmpty()) {
        "DIALING" -> currentAppText("拨号中", "Dialing")
        "RINGING" -> currentAppText("等待接听", "Waiting for Answer")
        "CONNECTED" -> currentAppText("通话中", "Connected")
        "ENDED" -> currentAppText("已结束", "Ended")
        "FAILED" -> currentAppText("通话失败", "Call Failed")
        "" -> "--"
        else -> state?.trim().orEmpty()
    }
}

internal fun localizedTranslationSessionState(state: String?): String {
    return when (state?.trim()?.uppercase().orEmpty()) {
        "DIALING" -> currentAppText("拨号中", "Dialing")
        "LANGUAGE_DETECTING" -> currentAppText("识别语言中", "Detecting Language")
        "TRANSLATING" -> currentAppText("实时翻译中", "Translating")
        "BYPASSING" -> currentAppText("直通中", "Passthrough")
        "ENDED" -> currentAppText("已结束", "Ended")
        "FAILED" -> currentAppText("翻译失败", "Translation Failed")
        "" -> "--"
        else -> state?.trim().orEmpty()
    }
}

internal fun displayLanguageLabel(code: String?): String {
    val normalized = code?.trim().orEmpty()
    val label = TranslationProviderLanguageChoices.firstOrNull {
        it.code.equals(normalized, ignoreCase = true)
    }?.label
    return when {
        label != null -> "$label ($normalized)"
        normalized.isBlank() -> "--"
        else -> normalized
    }
}

internal fun translationSubtitleRoleLabel(role: String?): String {
    val normalized = role?.lowercase().orEmpty()
    return when (normalized) {
        "caller" -> currentAppText("你说", "You")
        "callee" -> currentAppText("对方说", "Other Party")
        else -> role?.ifBlank { "--" } ?: "--"
    }
}

internal fun safeSubtitleRoleLabel(role: String?): String {
    val normalized = role?.lowercase().orEmpty()
    return when (normalized) {
        "caller" -> currentAppText("你说", "You")
        "callee" -> currentAppText("对方说", "Other Party")
        else -> role?.ifBlank { "--" } ?: "--"
    }
}
