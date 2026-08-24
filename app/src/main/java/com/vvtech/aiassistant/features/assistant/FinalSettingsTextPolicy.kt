package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.AssistantHistoryItem
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
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
    loading -> currentAppText("正在读取当前固定外呼号码", "Loading current outbound number")
    outboundNumber.isBlank() -> currentAppText("尚未配置固定外呼号码", "No fixed outbound number configured")
    configured -> currentAppText("当前生效：${maskPhone(outboundNumber)}", "Active: ${maskPhone(outboundNumber)}")
    else -> currentAppText("已保存但后端标记为未配置：${maskPhone(outboundNumber)}", "Saved, but backend marks it unconfigured: ${maskPhone(outboundNumber)}")
}

internal fun finalVoiceCloneStatusDescription(status: VoiceCloneStatusResponse?): String {
    if (status == null) {
        return currentAppText(
            "录完固定脚本后上传生成专属音色，当前仅用于 AI 外呼。",
            "Record the fixed script and upload it to create your voice. It is currently used only for AI outbound calls."
        )
    }
    return when (status.status.uppercase(Locale.ROOT)) {
        "PROCESSING", "GENERATING" -> currentAppText(
            "声音样本已上传，正在生成音色，完成后即可启用。",
            "Voice samples uploaded. Generating the voice now. You can enable it when it is ready."
        )
        "READY" -> if (status.active) {
            currentAppText(
                "当前 AI 外呼会优先使用这套克隆音色。",
                "AI outbound calls will prioritize this cloned voice."
            )
        } else {
            currentAppText(
                "声音已生成完成，点击启用后 AI 外呼会使用该音色。",
                "Voice generation is complete. Enable it to use this voice for AI outbound calls."
            )
        }
        "EXPIRED" -> status.lastError.ifBlank {
            currentAppText("旧版本声音样本已过期，请重新录制后再启用。", "The old voice samples expired. Please record again before enabling.")
        }
        "FAILED" -> status.lastError.ifBlank {
            currentAppText("生成失败，请重新录制并上传这段脚本。", "Generation failed. Please record and upload this script again.")
        }
        else -> currentAppText(
            "建议在安静环境录制，语速自然，避免背景音乐和回声。",
            "Record in a quiet environment, speak naturally, and avoid background music or echo."
        )
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
    if (loading) return currentAppText("同步中", "Syncing")
    if (status == null) return currentAppText("未读取", "Not Loaded")
    if (status.active) return currentAppText("已启用", "Enabled")
    return when (status.status.uppercase(Locale.ROOT)) {
        "READY" -> currentAppText("可启用", "Ready")
        "PROCESSING", "GENERATING" -> currentAppText("生成中", "Generating")
        "EXPIRED" -> currentAppText("已过期", "Expired")
        "FAILED" -> currentAppText("生成失败", "Generation Failed")
        "EMPTY", "NONE", "NOT_CONFIGURED" -> currentAppText("未录制", "Not Recorded")
        else -> status.status.ifBlank { currentAppText("未启用", "Not Enabled") }
    }
}

internal fun voiceCloneSettingsSubtitle(
    status: VoiceCloneStatusResponse?,
    loading: Boolean,
    error: String?
): String = when {
    loading -> currentAppText("正在同步声音克隆状态", "Syncing voice cloning status")
    !error.isNullOrBlank() -> error
    status == null -> currentAppText("点击进入后读取当前声音克隆状态", "Open to load current voice cloning status")
    status.active -> currentAppText("AI 外呼会优先使用已启用的克隆音色", "AI outbound calls will prioritize the enabled cloned voice")
    status.status.uppercase(Locale.ROOT) == "READY" -> currentAppText("已有 ${status.sampleCount} 条样本，可启用克隆音色", "${status.sampleCount} samples ready. You can enable the cloned voice")
    status.status.uppercase(Locale.ROOT) == "EXPIRED" -> status.lastError.ifBlank {
        currentAppText("旧版本声音样本已过期，请重新录制。", "Old voice samples expired. Please record again.")
    }
    status.lastError.isNotBlank() -> status.lastError
    else -> currentAppText(
        "当前状态：${status.status.ifBlank { "未配置" }}，样本 ${status.sampleCount} 条",
        "Current status: ${status.status.ifBlank { "Not Configured" }}, ${status.sampleCount} samples"
    )
}
