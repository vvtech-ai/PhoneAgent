package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class TaskCallSessionHistoryPlan(
    val taskId: String?,
    val callId: String?,
    val title: String,
    val status: String,
    val style: StatusStyle,
    val metaDetail: String,
    val finalState: Boolean,
    val phoneNumber: String = "",
    val resultText: String = "",
    val transcript: List<TranscriptLine> = emptyList()
)

internal fun taskCallSessionManualHangupHistoryPlan(
    taskId: String?,
    callId: String?,
    currentTitle: String,
    sceneType: String,
    currentCallUiMode: CallUiMode,
    responseStatusMessage: String,
    fallbackStatus: String
): TaskCallSessionHistoryPlan {
    val manualAbort = currentCallUiMode != CallUiMode.Human
    val historyStatus = if (manualAbort) {
        currentAppText("手动中止", "Stopped Manually")
    } else {
        currentAppText("人工接管", "Human Takeover")
    }
    return TaskCallSessionHistoryPlan(
        taskId = taskId,
        callId = callId,
        title = currentTitle.ifBlank { taskCallSessionSceneLabel(sceneType) },
        status = historyStatus,
        style = if (manualAbort) StatusStyle.Failure else StatusStyle.Success,
        metaDetail = responseStatusMessage.ifBlank { fallbackStatus },
        finalState = true
    )
}

internal fun taskCallSessionActiveHistoryPlan(
    response: CallSessionStatusResponse,
    currentTitle: String,
    facts: TaskCallSessionStatusFacts
): TaskCallSessionHistoryPlan? {
    return when {
        facts.humanMode -> TaskCallSessionHistoryPlan(
            taskId = response.taskId,
            callId = response.callId,
            title = taskCallSessionHistoryTitle(response, currentTitle),
            status = currentAppText("人工接管", "Human Takeover"),
            style = StatusStyle.Success,
            metaDetail = buildTaskCallHistoryMetaDetail(
                response = response,
                fallback = response.phoneNumber.ifBlank { response.statusMessage }
            ),
            finalState = true,
            phoneNumber = response.phoneNumber,
            resultText = response.resultText.ifBlank { response.statusMessage },
            transcript = taskCallSessionHistoryTranscript(response)
        )

        !facts.terminalCallState -> TaskCallSessionHistoryPlan(
            taskId = response.taskId,
            callId = response.callId,
            title = taskCallSessionHistoryTitle(response, currentTitle),
            status = currentAppText("AI代打中", "AI Calling"),
            style = StatusStyle.Success,
            metaDetail = buildTaskCallHistoryMetaDetail(
                response = response,
                fallback = response.statusMessage.ifBlank { response.phoneNumber }
            ),
            finalState = false,
            phoneNumber = response.phoneNumber,
            resultText = response.resultText.ifBlank { response.statusMessage },
            transcript = taskCallSessionHistoryTranscript(response)
        )

        else -> null
    }
}

internal fun taskCallSessionTerminalHistoryPlan(
    response: CallSessionStatusResponse,
    currentTitle: String,
    currentCallPageStatus: String,
    terminalPlan: CallSessionTerminalDisplayPlan
): TaskCallSessionHistoryPlan {
    return TaskCallSessionHistoryPlan(
        taskId = response.taskId,
        callId = response.callId,
        title = taskCallSessionHistoryTitle(response, currentTitle),
        status = terminalPlan.historyStatus,
        style = terminalPlan.historyStyle,
        metaDetail = buildTaskCallHistoryMetaDetail(
            response = response,
            fallback = response.statusMessage.ifBlank { currentCallPageStatus }
        ),
        finalState = true,
        phoneNumber = response.phoneNumber,
        resultText = response.resultText.ifBlank { response.statusMessage },
        transcript = taskCallSessionHistoryTranscript(response)
    )
}

private fun taskCallSessionHistoryTranscript(response: CallSessionStatusResponse): List<TranscriptLine> =
    parseTaskCallDialogueDetail(response.dialogueDetail)

private fun taskCallSessionHistoryTitle(
    response: CallSessionStatusResponse,
    currentTitle: String
): String {
    return response.targetName.ifBlank {
        currentTitle.ifBlank { taskCallSessionSceneLabel(response.sceneType) }
    }
}

private fun taskCallSessionSceneLabel(sceneType: String): String {
    return when (sceneType) {
        "FOOD_ORDERING" -> currentAppText("订餐任务", "Restaurant Booking")
        "HOTEL_BOOKING" -> currentAppText("订酒店", "Hotel Booking")
        "FLIGHT_BOOKING" -> currentAppText("订机票", "Flight Booking")
        "AI_CALL" -> currentAppText("帮打电话", "AI Call")
        else -> currentAppText("AI 任务", "AI Task")
    }
}
