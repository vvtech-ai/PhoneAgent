package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import java.util.Locale

private const val SameLanguagePassthroughMessage = "已检测到双方为同语种，当前改为直连"

internal fun localizeTranslationCallStatusText(raw: String?): String {
    val text = raw?.trim().orEmpty()
    if (text.isBlank()) return ""

    val normalized = text.replace('\uFF1A', ':')
    val withoutCallerPrefix = normalized.substringAfter("caller_to_callee:", normalized)
    val coreStatus = withoutCallerPrefix.substringAfter("callee_to_caller:", withoutCallerPrefix)
    val coreUppercase = coreStatus.uppercase(Locale.ROOT)

    return when {
        coreStatus.equals("provider_connected", ignoreCase = true) ->
            "翻译模型已连接"
        coreStatus.equals("provider_session_ready", ignoreCase = true) ->
            "翻译模型已就绪"
        coreStatus.equals("provider_session_finished", ignoreCase = true) ->
            "翻译会话已结束"
        coreStatus.equals("provider_response_done", ignoreCase = true) ->
            "本轮翻译已完成"
        coreStatus.equals("translation_socket_bound", ignoreCase = true) ->
            "翻译音频通道已绑定"
        coreStatus.equals("callee_audio_sink_bound", ignoreCase = true) ->
            "对方音频输出通道已绑定"
        coreStatus.equals("provider_timeout_reconnecting", ignoreCase = true) ->
            "翻译服务超时，正在重连"
        coreStatus.equals("audio_muted", ignoreCase = true) ->
            "翻译音频暂时静音"
        coreStatus.startsWith("provider_session_failed:", ignoreCase = true) ->
            "翻译会话已失败：${coreStatus.substringAfter(':').trim()}"
        coreStatus.startsWith("provider_reconnect_failed:", ignoreCase = true) ->
            "翻译服务重连失败：${coreStatus.substringAfter(':').trim()}"
        coreStatus.startsWith("provider_parse_error:", ignoreCase = true) ->
            "翻译服务返回解析失败：${coreStatus.substringAfter(':').trim()}"
        coreStatus.startsWith("provider_error:", ignoreCase = true) ->
            "翻译服务异常：${coreStatus.substringAfter(':').trim()}"
        coreStatus.startsWith("provider_closed:", ignoreCase = true) ->
            "翻译服务连接已关闭：${coreStatus.substringAfter(':').trim()}"
        normalized.equals("Detected the same language and switched to passthrough.", ignoreCase = true) ->
            SameLanguagePassthroughMessage
        normalized.equals("Current provider does not support realtime translation calls.", ignoreCase = true) ->
            "当前服务暂不支持实时翻译通话"
        normalized.equals("No active realtime translation call was found.", ignoreCase = true) ->
            "未找到正在进行的实时翻译通话"
        normalized.equals("User ended the realtime translation call.", ignoreCase = true) ->
            "已结束实时翻译通话"
        normalized.equals("Translation languages were manually overridden.", ignoreCase = true) ->
            "已手动更新翻译语种"
        normalized.equals("Doubao AST translation session connected.", ignoreCase = true) ->
            "实时翻译会话已连接"
        normalized.equals("Qwen realtime translation session connected.", ignoreCase = true) ->
            "实时翻译会话已连接"
        normalized.equals("Realtime translation session connected.", ignoreCase = true) ->
            "实时翻译会话已连接"
        normalized.equals("Realtime translation session is ready.", ignoreCase = true) ->
            "实时翻译会话已就绪"
        normalized.equals("Realtime translation is active.", ignoreCase = true) ->
            "实时翻译已启动"
        normalized.equals("Doubao AST translation session is ready.", ignoreCase = true) ->
            "实时翻译会话已就绪"
        normalized.equals("Doubao AST realtime translation is active.", ignoreCase = true) ->
            "实时翻译已启动"
        normalized.equals("Remote side is ringing. Waiting for answer.", ignoreCase = true) ->
            "对方正在响铃，等待接听"
        normalized.equals("The remote side is establishing the media session.", ignoreCase = true) ->
            "对方通话链路建立中"
        normalized.equals("Translation media bridge connected. Ready for bidirectional translation.", ignoreCase = true) ->
            "翻译通话已接通，可开始双向翻译"
        normalized.equals("Remote side ended the translation call.", ignoreCase = true) ->
            "对方已结束实时翻译通话"
        normalized.startsWith("Failed to start realtime translation session:", ignoreCase = true) ->
            "启动实时翻译会话失败：${normalized.substringAfter(':').trim()}"
        normalized.startsWith("Failed to launch SIP translation call:", ignoreCase = true) ->
            "发起实时翻译通话失败：${normalized.substringAfter(':').trim()}"
        normalized.startsWith("SIP REGISTER rejected:", ignoreCase = true) ->
            "SIP 注册被拒绝：${normalized.substringAfter(':').trim()}"
        normalized.startsWith("SIP INVITE rejected:", ignoreCase = true) ->
            "SIP 呼叫邀请被拒绝：${normalized.substringAfter(':').trim()}"
        normalized.equals("Timed out waiting for SIP response.", ignoreCase = true) ->
            "等待 SIP 响应超时"
        normalized.startsWith("SIP IO error:", ignoreCase = true) ->
            "SIP 网络异常：${normalized.substringAfter(':').trim()}"
        normalized.equals("SIP answered without a usable SDP media address.", ignoreCase = true) ->
            "对方已接听，但未返回可用的音频地址"
        normalized.equals("No live translation session was bound for this SIP call.", ignoreCase = true) ->
            "当前通话未绑定可用的实时翻译会话"
        normalized.startsWith("Failed to start translation media bridge:", ignoreCase = true) ->
            "启动翻译音频桥失败：${normalized.substringAfter(':').trim()}"
        coreUppercase == "DIALING" -> localizeTranslationCallState(coreStatus)
        coreUppercase in setOf("RINGING", "CONNECTED", "ENDED", "FAILED") ->
            localizeTranslationCallState(coreStatus)
        coreUppercase == "LANGUAGE_DETECTING" || coreUppercase == "TRANSLATING" ->
            localizeTranslationSessionState(coreStatus)
        normalized.contains("failed to connect", ignoreCase = true) ->
            "连接实时翻译服务失败"
        normalized.equals("Trying", ignoreCase = true) ->
            "正在尝试连接"
        normalized.equals("Ringing", ignoreCase = true) ->
            "对方正在响铃"
        normalized.equals("Session Progress", ignoreCase = true) ->
            "对方通话链路建立中"
        normalized.equals("Request Terminated", ignoreCase = true) ->
            "本次呼叫已终止"
        else -> text
    }
}

internal fun localizeTranslationCallState(raw: String?): String {
    return when (raw?.trim()?.uppercase(Locale.ROOT)) {
        "DIALING" -> "拨号中"
        "RINGING" -> "振铃中"
        "CONNECTED" -> "通话中"
        "ENDED" -> "已结束"
        "FAILED" -> "呼叫失败"
        else -> raw?.trim().orEmpty()
    }
}

internal fun localizeTranslationSessionState(raw: String?): String {
    return when (raw?.trim()?.uppercase(Locale.ROOT)) {
        "DIALING" -> "拨号准备中"
        "LANGUAGE_DETECTING" -> "识别语种中"
        "TRANSLATING" -> "实时翻译中"
        "ENDED" -> "翻译已结束"
        "FAILED" -> "翻译失败"
        else -> raw?.trim().orEmpty()
    }
}

internal fun TranslationCallStatusResponse.localizedForUi(): TranslationCallStatusResponse {
    return copy(
        callState = localizeTranslationCallState(callState),
        translationState = localizeTranslationSessionState(translationState),
        passthroughReason = localizeTranslationCallStatusText(passthroughReason).ifBlank { passthroughReason },
        statusMessage = localizeTranslationCallStatusText(statusMessage)
    )
}

@Suppress("UNUSED_PARAMETER")
internal fun shouldAutoSwitchRealtimeProviderOnStartup(
    activeProvider: String?,
    userHasManualSelection: Boolean
): Boolean {
    return false
}
