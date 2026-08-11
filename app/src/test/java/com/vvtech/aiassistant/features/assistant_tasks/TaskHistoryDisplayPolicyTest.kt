package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.ResultSummaryPayload
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.viewmodel.buildResultSummaryStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.summarizeHistoryMeta
import com.vvtech.aiassistant.features.assistant.viewmodel.toHistoryRecord
import com.vvtech.aiassistant.model.TaskListItem
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskHistoryDisplayPolicyTest {
    @Test
    fun summarizesTranscriptMetaAsRecorded() {
        val meta = """
            assistant: 您好，帮您确认包间。
            callee: 可以预留。
        """.trimIndent()

        assertEquals("通话摘要已记录", summarizeTaskHistoryMeta(meta))
    }

    @Test
    fun normalizesPersistedHistoryMetaKeepingPrefix() {
        val meta = "06-11 12:30 | assistant: 你好\ncallee: 好的"

        assertEquals("06-11 12:30 | 通话摘要已记录", normalizeTaskHistoryMeta(meta))
    }

    @Test
    fun buildsCallHistoryMetaDetailByFallbackPriority() {
        assertEquals(
            "最终文本",
            buildTaskCallHistoryMetaDetail(callStatus(resultText = "最终文本", resultReason = "原因"), "fallback")
        )
        assertEquals(
            "原因",
            buildTaskCallHistoryMetaDetail(callStatus(resultReason = "原因", statusMessage = "状态"), "fallback")
        )
        assertEquals(
            "状态",
            buildTaskCallHistoryMetaDetail(callStatus(statusMessage = "状态"), "fallback")
        )
        assertEquals("fallback", buildTaskCallHistoryMetaDetail(callStatus(), "fallback"))
    }

    @Test
    fun buildsTaskHistoryRecordDisplayWithStableStatusAndMeta() {
        val failed = buildTaskHistoryRecordDisplay(
            taskItem(
                status = "FAILED",
                originText = "给北海渔村打电话",
                callResultText = "assistant: 已沟通，未完成",
                createdAt = "2026-06-11T09:08:07"
            )
        )
        assertEquals("给北海渔村打电话", failed.title)
        assertEquals("未完成", failed.status)
        assertEquals(TaskHistoryStatusStyle.Failure, failed.style)
        assertEquals("06-11 09:08 | 通话摘要已记录", failed.meta)

        val completed = buildTaskHistoryRecordDisplay(
            taskItem(
                status = "COMPLETED",
                originText = "",
                finalResult = "预订成功。包间已预留。",
                createdAt = "bad-time"
            )
        )
        assertEquals("已完成任务", completed.title)
        assertEquals("已完成", completed.status)
        assertEquals(TaskHistoryStatusStyle.Success, completed.style)
        assertEquals("bad-time | 预订成功", completed.meta)
    }

    @Test
    fun legacyViewModelHelpersDelegateToTaskPolicy() {
        assertEquals("通话摘要已记录", summarizeHistoryMeta("system: 已记录"))

        val record = toHistoryRecord(
            taskItem(status = "SUCCESS", originText = "完成任务", finalResult = "已完成。", createdAt = "2026-06-11T10:00:00")
        )
        assertEquals("完成任务", record.title)
        assertEquals("已完成", record.status)
        assertEquals(StatusStyle.Success, record.style)
        assertEquals("06-11 10:00 | 已完成", record.meta)

        assertEquals(
            "2 路 COMPLETED",
            buildResultSummaryStatus(ResultSummaryPayload(headline = "2", detail = "", status = "COMPLETED"))
        )
    }

    @Test
    fun sourceBoundaryKeepsHistoryStrategyOutOfIndexPureFunctions() {
        val legacy = File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/Index9PureFunctions.kt").readText()
        val policy = File("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskHistoryDisplayPolicy.kt").readText()

        assertTrue(legacy.contains("summarizeTaskHistoryMeta(raw)"))
        assertTrue(legacy.contains("buildTaskHistoryRecordDisplay(item)"))
        assertTrue(legacy.contains("buildTaskResultSummaryStatus(result)"))
        assertFalse(legacy.contains("Regex(\"(?i)(assistant|callee|system):\")"))
        assertTrue(policy.contains("Regex(\"(?i)(assistant|callee|system):\")"))
    }

    private fun taskItem(
        status: String,
        originText: String,
        finalResult: String? = null,
        callResultText: String? = null,
        createdAt: String
    ): TaskListItem {
        return TaskListItem(
            taskId = "task-1",
            userId = "user-1",
            status = status,
            originText = originText,
            finalResult = finalResult,
            callResultText = callResultText,
            createdAt = createdAt
        )
    }

    private fun callStatus(
        resultText: String = "",
        resultReason: String = "",
        statusMessage: String = ""
    ): CallSessionStatusResponse {
        return CallSessionStatusResponse(
            callId = "call-1",
            taskId = "task-1",
            sceneType = "FOOD_ORDERING",
            targetName = "北海渔村",
            phoneNumber = "0755-86966889",
            callState = "ENDED",
            handoffMode = "COMPLETED",
            backendCallEnabled = true,
            handoffSupported = true,
            appRtcRequired = false,
            statusMessage = statusMessage,
            resultReason = resultReason,
            resultText = resultText,
            updatedAt = "2026-06-11T10:00:00"
        )
    }
}
