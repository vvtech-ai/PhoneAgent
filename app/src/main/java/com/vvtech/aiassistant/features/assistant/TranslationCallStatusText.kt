package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.TranslationCallStatusResponse
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

internal fun localizeTranslationCallStatusText(raw: String?): String {
    val text = raw?.trim().orEmpty()
    if (text.isBlank()) return ""

    val normalized = text.replace('\uFF1A', ':')
    val withoutCallerPrefix = normalized.substringAfter("caller_to_callee:", normalized)
    val coreStatus = withoutCallerPrefix.substringAfter("callee_to_caller:", withoutCallerPrefix)
    val coreUppercase = coreStatus.uppercase(Locale.ROOT)

    return when {
        coreStatus.equals("provider_connected", ignoreCase = true) ->
            currentAppText("翻译模型已连接", "Translation model connected")
        coreStatus.equals("provider_session_ready", ignoreCase = true) ->
            currentAppText("翻译模型已就绪", "Translation model ready")
        coreStatus.equals("provider_session_finished", ignoreCase = true) ->
            currentAppText("翻译会话已结束", "Translation session ended")
        coreStatus.equals("provider_response_done", ignoreCase = true) ->
            currentAppText("本轮翻译已完成", "Translation turn complete")
        coreStatus.equals("translation_socket_bound", ignoreCase = true) ->
            currentAppText("翻译音频通道已绑定", "Translation audio channel connected")
        coreStatus.equals("callee_audio_sink_bound", ignoreCase = true) ->
            currentAppText("对方音频输出通道已绑定", "Remote audio output connected")
        coreStatus.equals("provider_timeout_reconnecting", ignoreCase = true) ->
            currentAppText("翻译服务超时，正在重连", "Translation service timed out. Reconnecting")
        coreStatus.equals("audio_muted", ignoreCase = true) ->
            currentAppText("翻译音频暂时静音", "Translation audio temporarily muted")
        coreStatus.startsWith("provider_session_failed:", ignoreCase = true) ->
            currentAppText("翻译会话已失败：${coreStatus.substringAfter(':').trim()}", "Translation session failed: ${coreStatus.substringAfter(':').trim()}")
        coreStatus.startsWith("provider_reconnect_failed:", ignoreCase = true) ->
            currentAppText("翻译服务重连失败：${coreStatus.substringAfter(':').trim()}", "Translation service reconnect failed: ${coreStatus.substringAfter(':').trim()}")
        coreStatus.startsWith("provider_parse_error:", ignoreCase = true) ->
            currentAppText("翻译服务返回解析失败：${coreStatus.substringAfter(':').trim()}", "Translation service parse error: ${coreStatus.substringAfter(':').trim()}")
        coreStatus.startsWith("provider_error:", ignoreCase = true) ->
            currentAppText("翻译服务异常：${coreStatus.substringAfter(':').trim()}", "Translation service error: ${coreStatus.substringAfter(':').trim()}")
        coreStatus.startsWith("provider_closed:", ignoreCase = true) ->
            currentAppText("翻译服务连接已关闭：${coreStatus.substringAfter(':').trim()}", "Translation service connection closed: ${coreStatus.substringAfter(':').trim()}")
        normalized.equals("Detected the same language and switched to passthrough.", ignoreCase = true) ->
            currentAppText("已检测到双方为同语种，当前改为直连", "Detected the same language and switched to passthrough")
        normalized.equals("Current provider does not support realtime translation calls.", ignoreCase = true) ->
            currentAppText("当前服务暂不支持实时翻译通话", "Current provider does not support realtime translation calls")
        normalized.equals("No active realtime translation call was found.", ignoreCase = true) ->
            currentAppText("未找到正在进行的实时翻译通话", "No active realtime translation call was found")
        normalized.equals("User ended the realtime translation call.", ignoreCase = true) ->
            currentAppText("已结束实时翻译通话", "Realtime translation call ended")
        normalized.equals("Translation languages were manually overridden.", ignoreCase = true) ->
            currentAppText("已手动更新翻译语种", "Translation languages updated manually")
        normalized.equals("Doubao AST translation session connected.", ignoreCase = true) ->
            currentAppText("实时翻译会话已连接", "Realtime translation session connected")
        normalized.equals("Qwen realtime translation session connected.", ignoreCase = true) ->
            currentAppText("实时翻译会话已连接", "Realtime translation session connected")
        normalized.equals("Realtime translation session connected.", ignoreCase = true) ->
            currentAppText("实时翻译会话已连接", "Realtime translation session connected")
        normalized.equals("Realtime translation session is ready.", ignoreCase = true) ->
            currentAppText("实时翻译会话已就绪", "Realtime translation session ready")
        normalized.equals("Realtime translation is active.", ignoreCase = true) ->
            currentAppText("实时翻译已启动", "Realtime translation started")
        normalized.equals("Doubao AST translation session is ready.", ignoreCase = true) ->
            currentAppText("实时翻译会话已就绪", "Realtime translation session ready")
        normalized.equals("Doubao AST realtime translation is active.", ignoreCase = true) ->
            currentAppText("实时翻译已启动", "Realtime translation started")
        normalized.equals("Remote side is ringing. Waiting for answer.", ignoreCase = true) ->
            currentAppText("对方正在响铃，等待接听", "Remote side is ringing. Waiting for answer")
        normalized.equals("The remote side is establishing the media session.", ignoreCase = true) ->
            currentAppText("对方通话链路建立中", "Remote media session is connecting")
        normalized.equals("Translation media bridge connected. Ready for bidirectional translation.", ignoreCase = true) ->
            currentAppText("翻译通话已接通，可开始双向翻译", "Translation call connected. Bidirectional translation is ready")
        normalized.equals("Remote side ended the translation call.", ignoreCase = true) ->
            currentAppText("对方已结束实时翻译通话", "Remote side ended the translation call")
        normalized.startsWith("Failed to start realtime translation session:", ignoreCase = true) ->
            currentAppText("启动实时翻译会话失败：${normalized.substringAfter(':').trim()}", "Failed to start realtime translation session: ${normalized.substringAfter(':').trim()}")
        normalized.startsWith("Failed to launch SIP translation call:", ignoreCase = true) ->
            currentAppText("发起实时翻译通话失败：${normalized.substringAfter(':').trim()}", "Failed to launch realtime translation call: ${normalized.substringAfter(':').trim()}")
        normalized.startsWith("SIP REGISTER rejected:", ignoreCase = true) ->
            currentAppText("SIP 注册被拒绝：${normalized.substringAfter(':').trim()}", "SIP REGISTER rejected: ${normalized.substringAfter(':').trim()}")
        normalized.startsWith("SIP INVITE rejected:", ignoreCase = true) ->
            currentAppText("SIP 呼叫邀请被拒绝：${normalized.substringAfter(':').trim()}", "SIP INVITE rejected: ${normalized.substringAfter(':').trim()}")
        normalized.equals("Timed out waiting for SIP response.", ignoreCase = true) ->
            currentAppText("等待 SIP 响应超时", "Timed out waiting for SIP response")
        normalized.startsWith("SIP IO error:", ignoreCase = true) ->
            currentAppText("SIP 网络异常：${normalized.substringAfter(':').trim()}", "SIP IO error: ${normalized.substringAfter(':').trim()}")
        normalized.equals("SIP answered without a usable SDP media address.", ignoreCase = true) ->
            currentAppText("对方已接听，但未返回可用的音频地址", "SIP answered without a usable SDP media address")
        normalized.equals("No live translation session was bound for this SIP call.", ignoreCase = true) ->
            currentAppText("当前通话未绑定可用的实时翻译会话", "No live translation session was bound for this SIP call")
        normalized.startsWith("Failed to start translation media bridge:", ignoreCase = true) ->
            currentAppText("启动翻译音频桥失败：${normalized.substringAfter(':').trim()}", "Failed to start translation media bridge: ${normalized.substringAfter(':').trim()}")
        coreUppercase == "DIALING" -> localizeTranslationCallState(coreStatus)
        coreUppercase in setOf("RINGING", "CONNECTED", "ENDED", "FAILED") ->
            localizeTranslationCallState(coreStatus)
        coreUppercase == "LANGUAGE_DETECTING" || coreUppercase == "TRANSLATING" ->
            localizeTranslationSessionState(coreStatus)
        normalized.contains("failed to connect", ignoreCase = true) ->
            currentAppText("连接实时翻译服务失败", "Failed to connect to realtime translation service")
        normalized.equals("Trying", ignoreCase = true) ->
            currentAppText("正在尝试连接", "Trying to connect")
        normalized.equals("Ringing", ignoreCase = true) ->
            currentAppText("对方正在响铃", "Remote side is ringing")
        normalized.equals("Session Progress", ignoreCase = true) ->
            currentAppText("对方通话链路建立中", "Remote media session is connecting")
        normalized.equals("Request Terminated", ignoreCase = true) ->
            currentAppText("本次呼叫已终止", "Call request terminated")
        else -> text
    }
}

internal fun localizeTranslationCallState(raw: String?): String {
    return when (raw?.trim()?.uppercase(Locale.ROOT)) {
        "DIALING" -> currentAppText("拨号中", "Dialing")
        "RINGING" -> currentAppText("振铃中", "Ringing")
        "CONNECTED" -> currentAppText("通话中", "Connected")
        "ENDED" -> currentAppText("已结束", "Ended")
        "FAILED" -> currentAppText("呼叫失败", "Call Failed")
        else -> raw?.trim().orEmpty()
    }
}

internal fun localizeTranslationSessionState(raw: String?): String {
    return when (raw?.trim()?.uppercase(Locale.ROOT)) {
        "DIALING" -> currentAppText("拨号准备中", "Preparing Call")
        "LANGUAGE_DETECTING" -> currentAppText("识别语种中", "Detecting Language")
        "TRANSLATING" -> currentAppText("实时翻译中", "Translating")
        "ENDED" -> currentAppText("翻译已结束", "Translation Ended")
        "FAILED" -> currentAppText("翻译失败", "Translation Failed")
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
