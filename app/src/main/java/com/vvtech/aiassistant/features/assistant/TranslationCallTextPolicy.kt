package com.vvtech.aiassistant.features.assistant
internal fun subtitleRoleLabel(role: String): String = when (role.lowercase()) {
    "caller" -> "你说"
    "callee" -> "对方说"
    else -> role
}

internal fun localizedTranslationCallMessage(message: String?): String {
    val raw = message?.trim().orEmpty()
    if (raw.isBlank()) {
        return ""
    }
    return when {
        raw.equals("Remote side is ringing. Waiting for answer.", ignoreCase = true) ->
            "对方正在响铃，等待接听。"
        raw.equals("Preparing SIP call and translation streams.", ignoreCase = true) ->
            "正在准备 SIP 通话和实时翻译通道。"
        raw.equals("Translation media bridge connected. Ready for bidirectional translation.", ignoreCase = true) ->
            "通话已接通，实时翻译已准备就绪。"
        raw.equals("Detected the same language and switched to passthrough.", ignoreCase = true) ->
            "已检测到双方使用同一语种，当前为直通模式。"
        raw.equals("Translation languages were manually overridden.", ignoreCase = true) ->
            "语言设置已更新。"
        raw.equals("Current provider does not support realtime translation calls.", ignoreCase = true) ->
            "当前服务暂不支持实时翻译通话。"
        raw.equals("User ended the realtime translation call.", ignoreCase = true) ->
            "用户已结束实时翻译通话。"
        raw.equals("No active realtime translation call was found.", ignoreCase = true) ->
            "未找到正在进行的实时翻译通话。"
        raw.equals("Realtime translation session connected.", ignoreCase = true) ->
            "实时翻译会话已连接，正在识别语言。"
        raw.equals("Doubao AST translation session connected.", ignoreCase = true) ->
            "实时翻译会话已连接，正在识别语言。"
        raw.equals("Realtime translation session is ready.", ignoreCase = true) ->
            "实时翻译会话已准备就绪。"
        raw.equals("Realtime translation is active.", ignoreCase = true) ->
            "实时翻译已开启。"
        raw.equals("Doubao AST translation session is ready.", ignoreCase = true) ->
            "实时翻译会话已准备就绪。"
        raw.equals("Doubao AST realtime translation is active.", ignoreCase = true) ->
            "实时翻译已开启。"
        raw.equals("Translated subtitles updated.", ignoreCase = true) ->
            "译文字幕已更新。"
        raw.equals("Translation audio channel disconnected. Waiting for reconnection.", ignoreCase = true) ->
            "翻译音频通道已断开，正在等待重连。"
        raw.equals("Translation audio channel reconnected. Resuming realtime translation.", ignoreCase = true) ->
            "翻译音频通道已恢复，正在继续实时翻译。"
        raw.equals("Translation audio channel did not recover in time. The realtime translation call was ended automatically.", ignoreCase = true) ->
            "翻译音频通道长时间未恢复，系统已自动结束实时翻译通话。"
        raw.startsWith("Failed to start realtime translation session:", ignoreCase = true) ->
            "启动实时翻译会话失败：${raw.substringAfter(':').trim()}"
        raw.startsWith("Failed to launch SIP translation call:", ignoreCase = true) ->
            "发起 SIP 实时翻译通话失败：${raw.substringAfter(':').trim()}"
        raw.startsWith("Translation call failed before media bridge was ready:", ignoreCase = true) ->
            "实时翻译通话失败，媒体通道尚未就绪：${raw.substringAfter(':').trim()}"
        raw.startsWith("SIP REGISTER rejected:", ignoreCase = true) ->
            "SIP 注册被拒绝：${raw.substringAfter(':').trim()}"
        raw.startsWith("SIP INVITE rejected:", ignoreCase = true) ->
            "SIP 呼叫被拒绝：${raw.substringAfter(':').trim()}"
        raw.startsWith("SIP INVITE failed:", ignoreCase = true) ->
            "SIP 呼叫失败：${raw.substringAfter(':').trim()}"
        raw.equals("Timed out waiting for SIP REGISTER.", ignoreCase = true) ->
            "等待 SIP 注册响应超时。"
        raw.equals("Timed out waiting for SIP INVITE final response.", ignoreCase = true) ->
            "等待对方接听超时。"
        raw.equals("Timed out waiting for SIP response.", ignoreCase = true) ->
            "等待 SIP 响应超时。"
        raw.startsWith("SIP IO error:", ignoreCase = true) ->
            "SIP 网络异常：${raw.substringAfter(':').trim()}"
        raw.startsWith("Provider error:", ignoreCase = true) ->
            "翻译服务异常：${raw.substringAfter(':').trim()}"
        raw.equals("Remote side ended the translation call.", ignoreCase = true) ->
            "对方已结束实时翻译通话。"
        raw.equals("Translation call reached the max conversation window and was closed.", ignoreCase = true) ->
            "实时翻译通话已达到最长通话时长，系统已自动结束。"
        else -> raw
    }
}

internal fun localizedTranslationCallState(state: String?): String {
    return when (state?.trim()?.uppercase().orEmpty()) {
        "DIALING" -> "拨号中"
        "RINGING" -> "等待接听"
        "CONNECTED" -> "通话中"
        "ENDED" -> "已结束"
        "FAILED" -> "通话失败"
        "" -> "--"
        else -> state?.trim().orEmpty()
    }
}

internal fun localizedTranslationSessionState(state: String?): String {
    return when (state?.trim()?.uppercase().orEmpty()) {
        "DIALING" -> "拨号中"
        "LANGUAGE_DETECTING" -> "识别语言中"
        "TRANSLATING" -> "实时翻译中"
        "BYPASSING" -> "直通中"
        "ENDED" -> "已结束"
        "FAILED" -> "翻译失败"
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
        "caller" -> "你说"
        "callee" -> "对方说"
        else -> role?.ifBlank { "--" } ?: "--"
    }
}

internal fun safeSubtitleRoleLabel(role: String?): String {
    val normalized = role?.lowercase().orEmpty()
    return when (normalized) {
        "caller" -> "浣犺"
        "callee" -> "瀵规柟璇?"
        else -> role?.ifBlank { "--" } ?: "--"
    }
}
