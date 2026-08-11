package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.AssistantHistoryItem
import com.vvtech.aiassistant.core.model.CallSpecPayload
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


internal enum class PureVoiceBottomControlMode {
    Mic,
    Recording,
    Finalizing,
    Stop,
    Ended
}

internal fun resolvePureVoiceBottomControlMode(
    taskStatus: String,
    status: String,
    manuallyPaused: Boolean,
    apiAsrListening: Boolean = false,
    asrFinalizing: Boolean = false,
    processingTurn: Boolean = false,
    backgroundPaused: Boolean = false
): PureVoiceBottomControlMode {
    if (isReadOnlyConversationStatus(taskStatus)) {
        return PureVoiceBottomControlMode.Mic
    }
    if (canonicalConversationTaskStatus(taskStatus) in setOf("NETWORK_ERROR", "EXECUTION_ERROR")) {
        return PureVoiceBottomControlMode.Mic
    }
    if (canonicalConversationTaskStatus(taskStatus) in setOf("FAILED", "INCOMPLETE")) {
        return PureVoiceBottomControlMode.Mic
    }
    if (asrFinalizing) {
        return PureVoiceBottomControlMode.Finalizing
    }
    if (processingTurn) {
        return PureVoiceBottomControlMode.Stop
    }
    if (apiAsrListening) {
        return PureVoiceBottomControlMode.Recording
    }
    val normalizedStatus = status.trim()
    if (
        normalizedStatus == "对话已恢复，点击继续说话" ||
        normalizedStatus == "历史记录已恢复" ||
        normalizedStatus == "该任务已结束" ||
        normalizedStatus == "已恢复对话，可继续补充" ||
        normalizedStatus == "已暂停，返回后可继续" ||
        normalizedStatus == "你可以再点一下麦克风继续说" ||
        normalizedStatus == "Voice is ready. Please continue." ||
        normalizedStatus == "音声入力を続けられます。"
    ) {
        return PureVoiceBottomControlMode.Mic
    }
    return PureVoiceBottomControlMode.Mic
}

internal fun resolveSingleFlowPureVoiceBottomControlMode(
    taskStatus: String,
    status: String,
    manuallyPaused: Boolean,
    backgroundPaused: Boolean,
    listening: Boolean,
    asrFinalizing: Boolean = false,
    processingTurn: Boolean,
    aiSpeaking: Boolean
): PureVoiceBottomControlMode {
    if (asrFinalizing) {
        return PureVoiceBottomControlMode.Finalizing
    }
    if (manuallyPaused || backgroundPaused) {
        return PureVoiceBottomControlMode.Mic
    }
    if (listening) {
        return PureVoiceBottomControlMode.Recording
    }
    if (processingTurn || aiSpeaking) {
        return PureVoiceBottomControlMode.Stop
    }
    return resolvePureVoiceBottomControlMode(
        taskStatus = taskStatus,
        status = status,
        manuallyPaused = manuallyPaused,
        asrFinalizing = asrFinalizing,
        backgroundPaused = backgroundPaused
    )
}

internal fun resolvePureVoiceListeningState(
    manuallyPaused: Boolean,
    voiceConnecting: Boolean,
    listening: Boolean,
    apiAsrListening: Boolean
): Boolean {
    val recognizerReady = apiAsrListening || listening
    if (voiceConnecting && !recognizerReady) return false
    return !manuallyPaused && recognizerReady
}

internal fun resolveVoiceInputToolbarLabel(
    listening: Boolean,
    processingTurn: Boolean,
    manuallyPaused: Boolean,
    sceneType: String
): String? = when {
    listening -> null
    manuallyPaused -> "继续"
    processingTurn -> "AI在确认细节"
    sceneType == "FOOD_ORDERING" -> "继续补充"
    else -> "继续补充"
}

internal fun shouldForceNewTaskVoiceEntryStart(
    startInVoice: Boolean,
    resumeListeningOnly: Boolean,
    resumeExisting: Boolean,
    initialCommand: String?
): Boolean {
    return startInVoice &&
        !resumeListeningOnly &&
        !resumeExisting &&
        initialCommand.isNullOrBlank()
}

internal fun shouldSyncConversationBeforeVoiceResume(
    sessionId: String?,
    taskStatus: String,
    status: String,
    processingTurn: Boolean
): Boolean {
    if (sessionId.isNullOrBlank()) return false
    if (isReadOnlyConversationStatus(taskStatus)) return false
    val normalizedStatus = status.trim()
    return processingTurn ||
        normalizedStatus == "对话已恢复，点击继续说话" ||
        normalizedStatus == "已恢复对话，可继续补充" ||
        normalizedStatus == "已暂停，返回后可继续" ||
        normalizedStatus == "已暂停，点击继续说话"
}

internal fun shouldPersistExecutionErrorOnTaskExit(
    taskStatus: String,
    unresolvedTaskErrorStatus: String?,
    taskErrorRecoveryInProgress: Boolean
): Boolean {
    val unresolved = unresolvedTaskErrorStatus?.trim().orEmpty()
    if (unresolved.isNotBlank()) return true
    if (taskErrorRecoveryInProgress) return true
    return canonicalConversationTaskStatus(taskStatus) in setOf("NETWORK_ERROR", "EXECUTION_ERROR")
}

internal fun ConversationListItem.toCompletedTaskRecord(): FinalTaskRecord {
    val sceneTitle = assistantSceneTitle(sceneType.orEmpty(), sessionId)
    val normalizedTitle = title.orEmpty().trim()
    val displayTitle = when {
        normalizedTitle.isBlank() -> sceneTitle
        normalizedTitle.startsWith(sceneTitle) -> normalizedTitle
        else -> "$sceneTitle · $normalizedTitle"
    }
    val timeLabel = updatedAt?.trim()?.takeIf { it.isNotBlank() }
        ?: createdAt?.trim()?.takeIf { it.isNotBlank() }
        ?: "已完成"
    return FinalTaskRecord(
        title = displayTitle,
        status = conversationStatusLabel(status),
        detail = timeLabel,
        sceneType = sceneType,
        sourceText = normalizedTitle,
        notificationId = "conversation_$sessionId",
        startedAt = timeLabel
    )
}
