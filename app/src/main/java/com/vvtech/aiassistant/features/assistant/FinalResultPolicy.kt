package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_tasks.TaskFinalResultCallInput
import com.vvtech.aiassistant.features.assistant_tasks.TaskFinalResultHistoryInput
import com.vvtech.aiassistant.features.assistant_tasks.TaskFinalResultPageState
import com.vvtech.aiassistant.features.assistant_tasks.TaskFinalResultStatusStyle
import com.vvtech.aiassistant.features.assistant_tasks.TaskFinalResultSummaryInput
import com.vvtech.aiassistant.features.assistant_tasks.buildTaskFinalResultPageState
import com.vvtech.aiassistant.features.assistant_tasks.taskFinalResultIsSuccess

internal fun buildFinalResultPageState(
    restaurantName: String,
    sceneType: String,
    summary: SummaryData?,
    callData: CallPageData,
    historyRecord: HistoryRecord?
): TaskFinalResultPageState {
    return buildTaskFinalResultPageState(
        restaurantName = restaurantName,
        sceneType = sceneType,
        summary = summary?.toTaskFinalResultSummaryInput(),
        callData = callData.toTaskFinalResultCallInput(),
        historyRecord = historyRecord?.toTaskFinalResultHistoryInput()
    )
}

private fun SummaryData.toTaskFinalResultSummaryInput(): TaskFinalResultSummaryInput {
    return TaskFinalResultSummaryInput(
        task = task,
        targetLabel = targetLabel,
        target = target,
        timeLabel = timeLabel,
        time = time,
        extra = extra,
        contactLabel = contactLabel,
        contactValue = contactValue,
        detailLabel = detailLabel,
        detailValue = detailValue
    )
}

private fun CallPageData.toTaskFinalResultCallInput(): TaskFinalResultCallInput {
    return TaskFinalResultCallInput(
        name = name,
        sub = sub,
        status = status,
        transcriptTexts = transcript.map { it.text }
    )
}

private fun HistoryRecord.toTaskFinalResultHistoryInput(): TaskFinalResultHistoryInput {
    return TaskFinalResultHistoryInput(
        title = title,
        status = status,
        style = style.toTaskFinalResultStatusStyle(),
        meta = meta
    )
}

private fun StatusStyle.toTaskFinalResultStatusStyle(): TaskFinalResultStatusStyle {
    return when (this) {
        StatusStyle.Success -> TaskFinalResultStatusStyle.Success
        StatusStyle.Failure -> TaskFinalResultStatusStyle.Failure
    }
}

@Suppress("unused")
private fun finalResultIsSuccess(
    statusText: String,
    detailSource: String,
    style: StatusStyle?
): Boolean {
    return taskFinalResultIsSuccess(
        statusText = statusText,
        detailSource = detailSource,
        style = style?.toTaskFinalResultStatusStyle()
    )
}
