package com.vvtech.aiassistant.features.assistant_home

import com.vvtech.aiassistant.features.assistant.ClarificationStep

internal fun resolveAssistantHomeProgressStage(
    taskStatus: String,
    taskStarted: Boolean,
    voiceRecording: Boolean,
    processingTurn: Boolean,
    clarificationSteps: List<ClarificationStep>
): Int {
    val status = taskStatus.trim().uppercase()
    val progressText = clarificationSteps.joinToString("\n") { step ->
        buildString {
            appendLine(step.text)
            appendLine(step.thinking.orEmpty())
            step.callStatusEvents.forEach(::appendLine)
            step.partialToolCalls.forEach { appendLine(it.name) }
            step.toolCalls.orEmpty().forEach { appendLine(it.name) }
        }
    }
    val hasRunningBatchCallResult = clarificationSteps.any { step ->
        step.batchCallResult?.status.equals("RUNNING", ignoreCase = true)
    }
    val hasFinalBatchCallResult = clarificationSteps.any { step ->
        val result = step.batchCallResult
        result != null && !result.status.equals("RUNNING", ignoreCase = true)
    }
    val hasResult = status in setOf("SUCCESS", "COMPLETED", "FAILED", "CANCELLED", "CANCELED", "PENDING") ||
        hasFinalBatchCallResult ||
        progressText.contains("批量外呼完成") ||
        progressText.contains("执行结果") ||
        progressText.contains("邀约回执") ||
        progressText.contains("任务已完成")
    val hasCallExecution = hasRunningBatchCallResult ||
        clarificationSteps.any { it.callStatusEvents.isNotEmpty() } ||
        progressText.contains("makeCall") ||
        progressText.contains("makeBatchCalls") ||
        progressText.contains("正在拨打") ||
        progressText.contains("正在重拨") ||
        progressText.contains("正在同时拨打") ||
        progressText.contains("通话执行中") ||
        progressText.contains("通话完成")
    val hasRequirementConfirmation = clarificationSteps.any {
        it.callConfirmSpec != null || it.streaming || !it.thinking.isNullOrBlank()
    } ||
        progressText.contains("识别当前任务为") ||
        progressText.contains("补全") ||
        progressText.contains("确认外呼") ||
        progressText.contains("搜到") ||
        progressText.contains("找到") ||
        progressText.contains("确认开始")

    return when {
        hasResult -> 4
        hasCallExecution -> 3
        hasRequirementConfirmation -> 2
        taskStarted || voiceRecording || processingTurn || clarificationSteps.isNotEmpty() -> 1
        else -> 1
    }
}
