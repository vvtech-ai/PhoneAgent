package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.viewmodel.isTerminalTask
import com.vvtech.aiassistant.features.assistant.viewmodel.normalizePersistedHistoryMeta
import com.vvtech.aiassistant.features.assistant.viewmodel.taskSortKey
import com.vvtech.aiassistant.features.assistant.viewmodel.toHistoryRecord
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.AssistantCallHistoryItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.repository.TaskRepository
import java.time.LocalDateTime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter
import java.time.ZoneId

internal data class TaskCallHistoryEntry(
    val key: String,
    val taskId: String,
    val callId: String? = null,
    val callAttemptId: String = taskCallHistoryAttemptIdFromKey(key, callId),
    val title: String,
    val status: String,
    val style: StatusStyle,
    val meta: String,
    val sortAt: LocalDateTime,
    val finalState: Boolean,
    val phoneNumber: String = "",
    val dateText: String = "",
    val startTimeText: String = "",
    val endTimeText: String = "",
    val durationText: String = "",
    val resultText: String = "",
    val transcript: List<TranscriptLine> = emptyList()
)

internal data class TaskCallHistoryControllerDeps(
    val taskRepository: TaskRepository,
    val stateHolder: TaskCallHistoryUiStateHolder,
    val scope: CoroutineScope,
    val userIdProvider: () -> String,
    val timelineItemsProvider: () -> List<ConversationTimelineItem>,
)

internal class TaskCallHistoryController(
    private val deps: TaskCallHistoryControllerDeps
) {
    var timelineCallHistory: List<TaskCallHistoryEntry> = emptyList()
        private set
    private var serverCallHistory: List<TaskCallHistoryEntry> = emptyList()

    /** The only durable call-history ingress: replace the complete server-ledger projection. */
    fun acceptTimelineProjection(sessionId: String, items: List<ConversationTimelineItem>) {
        require(sessionId.isNotBlank()) { "sessionId is required" }
        timelineCallHistory = ConversationTimelineCallHistoryAdapter.adapt(items)
        pushMergedHistoryToUi()
    }

    fun pushMergedHistoryToUi(tasks: List<TaskListItem>? = null) {
        val durableHistory = mergedCallHistory()
        val projectedTaskIds = durableHistory
            .map { it.taskId }
            .filter { it.isNotBlank() }
            .toSet()
        val backendRecords = (tasks ?: emptyList())
            .filter(::isTerminalTask)
            .filterNot { it.taskId in projectedTaskIds }
            .sortedByDescending(::taskSortKey)
            .map(::toHistoryRecord)
        val projectedRecords = durableHistory
            .sortedByDescending { it.sortAt }
            .map {
                HistoryRecord(
                    title = it.title,
                    status = it.status,
                    style = it.style,
                    meta = normalizePersistedHistoryMeta(it.meta),
                    occurredAtMillis = it.sortAt.takeUnless { value -> value == LocalDateTime.MIN }
                        ?.atZone(ZoneId.systemDefault())
                        ?.toInstant()
                        ?.toEpochMilli(),
                    phoneNumber = it.phoneNumber,
                    dateText = it.dateText,
                    startTimeText = it.startTimeText,
                    endTimeText = it.endTimeText,
                    durationText = it.durationText,
                    resultText = it.resultText,
                    transcript = it.transcript,
                    taskId = it.taskId,
                    callId = it.callId.orEmpty()
                )
            }
        deps.stateHolder.showHistoryRecords(projectedRecords + backendRecords)
    }

    fun refreshHistory() {
        deps.scope.launch {
            deps.stateHolder.markHistoryLoading()
            val userId = deps.userIdProvider()
            val historyResult = runCatching { deps.taskRepository.listCallHistory(userId) }
            historyResult.onSuccess { records -> serverCallHistory = records.mapNotNull(::serverHistoryEntry) }
            val timelineItems = deps.timelineItemsProvider()
            timelineCallHistory = ConversationTimelineCallHistoryAdapter.adapt(timelineItems)
            runCatching { deps.taskRepository.listTasks(userId) }
                .onSuccess { tasks ->
                    pushMergedHistoryToUi(tasks)
                }
                .onFailure { throwable ->
                    pushMergedHistoryToUi()
                    deps.stateHolder.showHistoryError(throwable.message ?: "历史任务加载失败")
                }
            historyResult.exceptionOrNull()?.let { throwable ->
                if (serverCallHistory.isEmpty()) {
                    deps.stateHolder.showHistoryError(throwable.message ?: "通话历史加载失败")
                }
            }
        }
    }

    private fun mergedCallHistory(): List<TaskCallHistoryEntry> {
        val merged = linkedMapOf<String, TaskCallHistoryEntry>()
        serverCallHistory.forEach { merged[it.callAttemptId] = it }
        timelineCallHistory.forEach { timeline ->
            val stored = merged[timeline.callAttemptId]
            merged[timeline.callAttemptId] = if (stored == null) timeline else stored.copy(
                title = stored.title.ifBlank { timeline.title },
                status = timeline.status.ifBlank { stored.status },
                style = timeline.style,
                meta = stored.meta.ifBlank { timeline.meta },
                finalState = stored.finalState || timeline.finalState,
                resultText = stored.resultText.ifBlank { timeline.resultText },
                transcript = stored.transcript.ifEmpty { timeline.transcript },
            )
        }
        return merged.values.sortedByDescending { it.sortAt }
    }

    private fun serverHistoryEntry(item: AssistantCallHistoryItem): TaskCallHistoryEntry? {
        val taskId = item.taskId?.trim().orEmpty().ifBlank { item.callId }
        val attemptId = item.callAttemptId?.trim().orEmpty().ifBlank { item.callId }
        val status = item.callState?.trim().orEmpty().ifBlank { item.resultCode?.trim().orEmpty() }
        val normalized = status.uppercase()
        if (!isTerminalAssistantCallHistoryState(normalized)) return null
        val result = item.resultCode?.trim()?.uppercase().orEmpty()
        val failed = listOf("FAIL", "CANCEL", "REJECT", "NOT_FOUND", "NEEDS_RECALL")
            .any { marker -> marker in normalized || marker in result }
        val createdAt = ConversationTimelineCallHistoryAdapter.run { item.createdAt.toHistoryDateTime() }
        val updatedAt = ConversationTimelineCallHistoryAdapter.run { item.updatedAt.toHistoryDateTime() }
        val transcript = parseTaskCallDialogueDetail(item.dialogueDetail.orEmpty())
        val displayMeta = callHistoryReceiptSummary(
            resultReason = item.resultReason,
            statusMessage = item.statusMessage,
            dialogueSummary = item.dialogueSummary,
            transcript = transcript,
            success = !failed,
        )
        return TaskCallHistoryEntry(
            key = "task=$taskId|attempt=$attemptId",
            taskId = taskId,
            callId = item.callId,
            callAttemptId = attemptId,
            title = callHistoryDisplayTitle(item.targetName, item.phoneNumber),
            status = status,
            style = if (failed) StatusStyle.Failure else StatusStyle.Success,
            meta = displayMeta,
            sortAt = updatedAt ?: createdAt ?: LocalDateTime.MIN,
            finalState = true,
            phoneNumber = item.phoneNumber?.trim().orEmpty(),
            dateText = createdAt?.format(DateTimeFormatter.ofPattern("yyyy-MM-dd")).orEmpty(),
            startTimeText = createdAt?.format(DateTimeFormatter.ofPattern("HH:mm")).orEmpty(),
            endTimeText = updatedAt?.format(DateTimeFormatter.ofPattern("HH:mm")).orEmpty(),
            durationText = ConversationTimelineCallHistoryAdapter.historyDuration(createdAt, updatedAt),
            resultText = displayMeta,
            transcript = transcript,
        )
    }
}

internal fun isTerminalAssistantCallHistoryState(state: String?): Boolean {
    val normalized = state?.trim()?.uppercase().orEmpty()
    return normalized in setOf(
        "COMPLETED", "SUCCESS", "DONE", "FINISHED", "ENDED",
        "FAILED", "CANCELLED", "REJECTED", "NOT_FOUND",
    ) ||
        listOf("FAIL", "CANCEL", "REJECT").any(normalized::contains)
}

internal fun taskCallHistoryKey(taskId: String?, callId: String?): String? {
    val safeTaskId = taskId?.trim().orEmpty()
    val safeCallId = callId?.trim().orEmpty()
    return when {
        safeTaskId.isNotBlank() && safeCallId.isNotBlank() -> "task=$safeTaskId|call=$safeCallId"
        safeTaskId.isNotBlank() -> taskCallHistoryPendingAttemptKey(safeTaskId)
        safeCallId.isNotBlank() -> safeCallId
        else -> null
    }
}
