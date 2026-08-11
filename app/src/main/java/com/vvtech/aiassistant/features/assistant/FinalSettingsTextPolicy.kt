package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.AssistantHistoryItem
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.model.ConversationDetail
import com.vvtech.aiassistant.model.ConversationListItem
import com.vvtech.aiassistant.model.ReservationSlot
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale


internal fun outboundNumberSubtitle(
    outboundNumber: String,
    loading: Boolean,
    configured: Boolean
): String = when {
    loading -> "正在读取当前固定外呼号码"
    outboundNumber.isBlank() -> "尚未配置固定外呼号码"
    configured -> "当前生效：${maskPhone(outboundNumber)}"
    else -> "已保存但后端标记为未配置：${maskPhone(outboundNumber)}"
}

internal fun finalVoiceCloneStatusDescription(status: VoiceCloneStatusResponse?): String {
    if (status == null) {
        return "录完固定脚本后上传生成专属音色，当前仅用于 AI 外呼。"
    }
    return when (status.status.uppercase(Locale.ROOT)) {
        "PROCESSING", "GENERATING" -> "声音样本已上传，正在生成音色，完成后即可启用。"
        "READY" -> if (status.active) {
            "当前 AI 外呼会优先使用这套克隆音色。"
        } else {
            "声音已生成完成，点击启用后 AI 外呼会使用该音色。"
        }
        "EXPIRED" -> status.lastError.ifBlank { "旧版本声音样本已过期，请重新录制后再启用。" }
        "FAILED" -> status.lastError.ifBlank { "生成失败，请重新录制并上传这段脚本。" }
        else -> "建议在安静环境录制，语速自然，避免背景音乐和回声。"
    }
}

internal fun finalHasUploadedVoiceClone(status: VoiceCloneStatusResponse?): Boolean {
    if (status == null || status.sampleCount <= 0) return false
    return when (status.status.uppercase(Locale.ROOT)) {
        "PROCESSING", "GENERATING", "READY" -> true
        else -> false
    }
}

internal fun formatVoiceCloneDuration(durationMs: Long): String {
    val seconds = durationMs / 1000.0
    return String.format(Locale.US, "%.1f 秒", seconds)
}

internal fun voiceCloneStatusLabel(
    status: VoiceCloneStatusResponse?,
    loading: Boolean
): String {
    if (loading) return "同步中"
    if (status == null) return "未读取"
    if (status.active) return "已启用"
    return when (status.status.uppercase(Locale.ROOT)) {
        "READY" -> "可启用"
        "PROCESSING", "GENERATING" -> "生成中"
        "EXPIRED" -> "已过期"
        "FAILED" -> "生成失败"
        "EMPTY", "NONE", "NOT_CONFIGURED" -> "未录制"
        else -> status.status.ifBlank { "未启用" }
    }
}

internal fun voiceCloneSettingsSubtitle(
    status: VoiceCloneStatusResponse?,
    loading: Boolean,
    error: String?
): String = when {
    loading -> "正在同步声音克隆状态"
    !error.isNullOrBlank() -> error
    status == null -> "点击进入后读取当前声音克隆状态"
    status.active -> "AI 外呼会优先使用已启用的克隆音色"
    status.status.uppercase(Locale.ROOT) == "READY" -> "已有 ${status.sampleCount} 条样本，可启用克隆音色"
    status.status.uppercase(Locale.ROOT) == "EXPIRED" -> status.lastError.ifBlank { "旧版本声音样本已过期，请重新录制。" }
    status.lastError.isNotBlank() -> status.lastError
    else -> "当前状态：${status.status.ifBlank { "未配置" }}，样本 ${status.sampleCount} 条"
}
