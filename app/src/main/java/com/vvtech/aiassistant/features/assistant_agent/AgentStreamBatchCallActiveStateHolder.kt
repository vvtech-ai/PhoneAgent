package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalPolicy
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalStepInput
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallFinalStepPatch
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallProgressInput
import com.vvtech.aiassistant.features.assistant_tasks.TaskBatchCallProgressPolicy

internal data class AgentStreamBatchCallProgressUpdate(
    val handled: Boolean,
    val snapshot: BatchCallResultPayload?
)

internal class AgentStreamBatchCallActiveStateHolder {
    private var activeBatchId: String? = null
    private var activeStepIndex: Int = -1
    private var activeTotalHint: Int = 0
    private val activeItems = linkedMapOf<Int, BatchCallItemResultPayload>()

    fun isActive(): Boolean = !activeBatchId.isNullOrBlank() && activeStepIndex >= 0

    fun isActiveStep(stepIndex: Int): Boolean = isActive() && activeStepIndex == stepIndex

    fun currentBatchId(): String = activeBatchId.orEmpty()

    fun markStream(stepIndex: Int, batchId: String?, total: Int) {
        val normalizedBatchId = batchId?.trim()?.takeIf { it.isNotBlank() }
        val existingBatchId = activeBatchId
        val shouldResetItems = activeStepIndex >= 0 &&
            (activeStepIndex != stepIndex ||
                (normalizedBatchId != null &&
                    existingBatchId != null &&
                    existingBatchId != normalizedBatchId &&
                    !existingBatchId.startsWith(PENDING_BATCH_PREFIX)))
        if (shouldResetItems) {
            activeItems.clear()
            activeTotalHint = 0
        }
        activeStepIndex = stepIndex
        activeBatchId = normalizedBatchId ?: existingBatchId ?: "$PENDING_BATCH_PREFIX$stepIndex"
        if (total > 0) {
            activeTotalHint = maxOf(activeTotalHint, total)
        }
    }

    fun clear(): Boolean {
        val hadActiveBatchCall = isActive()
        activeBatchId = null
        activeStepIndex = -1
        activeTotalHint = 0
        activeItems.clear()
        return hadActiveBatchCall
    }

    fun applyProgress(
        stepIndex: Int,
        event: AgentStreamEvent.StatusDelta,
        text: String
    ): AgentStreamBatchCallProgressUpdate {
        val batchId = event.batchId?.trim()?.takeIf { it.isNotBlank() }
        val hasBatchProgress = event.progressOnly || batchId != null || event.total > 0 || event.itemIndex > 0
        if (!hasBatchProgress) return AgentStreamBatchCallProgressUpdate(handled = false, snapshot = null)

        markStream(stepIndex = stepIndex, batchId = batchId, total = event.total)
        if (event.itemIndex > 0 && event.targetName.isNotBlank()) {
            activeItems[event.itemIndex] = TaskBatchCallProgressPolicy.buildItem(
                input = TaskBatchCallProgressInput(
                    batchId = event.batchId,
                    itemIndex = event.itemIndex,
                    targetName = event.targetName,
                    phoneNumber = event.phoneNumber,
                    status = event.batchStatus,
                    text = text
                ),
                existing = activeItems[event.itemIndex]
            )
        }
        return AgentStreamBatchCallProgressUpdate(handled = true, snapshot = snapshot())
    }

    fun buildFinalStepPatch(
        currentText: String,
        currentBatchCallResult: BatchCallResultPayload?,
        currentCallStatusEvents: List<String>,
        payloadText: String,
        payloadBatchCallResult: BatchCallResultPayload?
    ): TaskBatchCallFinalStepPatch {
        return TaskBatchCallFinalPolicy.buildStepPatch(
            TaskBatchCallFinalStepInput(
                currentText = currentText,
                currentBatchCallResult = currentBatchCallResult,
                currentCallStatusEvents = currentCallStatusEvents,
                payloadText = payloadText,
                payloadBatchCallResult = payloadBatchCallResult,
                fallbackBatchCallResult = if (payloadBatchCallResult == null && currentBatchCallResult == null) {
                    snapshot()
                } else {
                    null
                }
            )
        )
    }

    fun snapshot(): BatchCallResultPayload? {
        return TaskBatchCallProgressPolicy.buildSnapshot(
            totalHint = activeTotalHint,
            items = activeItems.toSortedMap().values.toList(),
            batchId = activeBatchId?.takeUnless { it.startsWith(PENDING_BATCH_PREFIX) },
        )
    }

    private companion object {
        const val PENDING_BATCH_PREFIX = "pending:"
    }
}
