package com.vvtech.aiassistant.features.assistant

import androidx.compose.ui.graphics.Color
import com.vvtech.aiassistant.features.assistant_tasks.TaskConversationStatusKind
import com.vvtech.aiassistant.features.assistant_tasks.canonicalConversationTaskStatus as taskCanonicalConversationTaskStatus
import com.vvtech.aiassistant.features.assistant_tasks.backendTaskStatusLabel as taskBackendTaskStatusLabel
import com.vvtech.aiassistant.features.assistant_tasks.conversationStatusLabel as taskConversationStatusLabel
import com.vvtech.aiassistant.features.assistant_tasks.isCompletedConversationStatus as taskIsCompletedConversationStatus
import com.vvtech.aiassistant.features.assistant_tasks.isReadOnlyConversationStatus as taskIsReadOnlyConversationStatus
import com.vvtech.aiassistant.features.assistant_tasks.normalizeConversationTaskStatus as taskNormalizeConversationTaskStatus
import com.vvtech.aiassistant.features.assistant_tasks.taskConversationStatusKind
import com.vvtech.aiassistant.features.assistant_tasks.taskStatusDisplayLabel
import com.vvtech.aiassistant.features.assistant_tasks.taskStatusHasTechnicalFailureSignal

internal typealias FinalTaskStatusKind = TaskConversationStatusKind

internal fun canonicalConversationTaskStatus(status: String): String =
    taskCanonicalConversationTaskStatus(status)

internal fun finalTaskStatusKind(status: String): FinalTaskStatusKind {
    return taskConversationStatusKind(status)
}

internal fun finalTaskHasTechnicalFailureSignal(normalized: String, uppercase: String): Boolean {
    return taskStatusHasTechnicalFailureSignal(normalized, uppercase)
}

internal fun normalizeConversationTaskStatus(
    rawStatus: String,
    detailStatus: String? = null,
): String {
    return taskNormalizeConversationTaskStatus(rawStatus, detailStatus)
}

internal fun conversationStatusLabel(status: String): String {
    return taskConversationStatusLabel(status)
}

internal fun finalTaskStatusDisplayLabel(status: String): String {
    return taskStatusDisplayLabel(status)
}

internal fun isCompletedConversationStatus(status: String): Boolean {
    return taskIsCompletedConversationStatus(status)
}

internal fun isReadOnlyConversationStatus(status: String): Boolean {
    return taskIsReadOnlyConversationStatus(status)
}

internal fun backendTaskStatusLabel(status: String): String {
    return taskBackendTaskStatusLabel(status)
}

internal fun finalTaskStatusColor(status: String): Color = when (finalTaskStatusKind(status)) {
    FinalTaskStatusKind.Completed -> Color(0xFF1F8F46)
    FinalTaskStatusKind.Incomplete -> Color(0xFFFF9F0A)
    FinalTaskStatusKind.Running -> Color(0xFF3B82F6)
    FinalTaskStatusKind.ExecutionError -> Color(0xFFDC2626)
}
