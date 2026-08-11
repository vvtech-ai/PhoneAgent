package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.buildFinalResultPageState
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskFinalResultPagePolicyTest {
    @Test
    fun buildsSuccessfulRestaurantResultPageState() {
        val state = buildTaskFinalResultPageState(
            restaurantName = "",
            sceneType = "GENERAL",
            summary = restaurantSummary(),
            callData = restaurantCallInput(),
            historyRecord = TaskFinalResultHistoryInput(
                title = "北海渔村",
                status = "已完成",
                style = TaskFinalResultStatusStyle.Success,
                meta = "刚刚"
            )
        )

        assertEquals("已完成", state.badge)
        assertTrue(state.success)
        assertFalse(state.partial)
        assertEquals("北海渔村", state.title)
        assertTrue(state.meta.contains("订餐任务"))
        assertTrue(state.meta.contains("结果已整理"))
        assertEquals("预订结果", state.rows[0].label)
        assertTrue(state.rows.any { it.label == "时间" && it.value.contains("今晚六点") })
        assertTrue(state.rows.any { it.label == "联系方式" && it.value.contains("188") })
    }

    @Test
    fun failureSignalBuildsIncompleteState() {
        val state = buildTaskFinalResultPageState(
            restaurantName = "北海渔村",
            sceneType = "FOOD_ORDERING",
            summary = null,
            callData = TaskFinalResultCallInput(
                name = "",
                sub = "包间预订",
                status = "COMPLETED",
                transcriptTexts = listOf("商家说当前无空位，预订未成功")
            ),
            historyRecord = null
        )

        assertEquals("未完成", state.badge)
        assertFalse(state.success)
        assertEquals("北海渔村", state.title)
        assertTrue(state.meta.contains("需要后续处理"))
        assertEquals("预订结果", state.rows[0].label)
        assertTrue(state.rows[0].value.contains("无空位"))
    }

    @Test
    fun legacyFinalResultEntrypointReturnsTaskBoundaryState() {
        val state = buildFinalResultPageState(
            restaurantName = "",
            sceneType = "GENERAL",
            summary = SummaryData(
                task = "订餐",
                targetLabel = "餐厅",
                target = "北海渔村",
                timeLabel = "时间",
                time = "今晚六点",
                extraLabel = "备注",
                extra = "包间",
                contactLabel = "联系方式",
                contactValue = "18823189131"
            ),
            callData = CallPageData(
                name = "北海渔村",
                sub = "AI 通话",
                status = "已完成",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Assistant, "包间已确认订好")
                )
            ),
            historyRecord = HistoryRecord("北海渔村", "已完成", StatusStyle.Success, "刚刚")
        )

        assertEquals(TaskFinalResultPageState::class, state::class)
        assertEquals("已完成", state.badge)
        assertTrue(state.success)
        assertEquals("北海渔村", state.title)
        assertEquals("预订结果", state.rows.first().label)
    }

    @Test
    fun taskPolicyDoesNotDependOnLegacyAssistantPackage() {
        val taskPolicy =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskFinalResultPagePolicy.kt")
                .readText()
        val legacyPolicy =
            File("src/main/java/com/vvtech/aiassistant/features/assistant/FinalResultPolicy.kt")
                .readText()
        val resultPage =
            File("src/main/java/com/vvtech/aiassistant/features/assistant/FinalResultPage.kt")
                .readText()

        assertFalse(taskPolicy.contains("features.assistant."))
        assertTrue(legacyPolicy.contains("buildTaskFinalResultPageState"))
        assertFalse(legacyPolicy.contains("toFinalResultPageState"))
        assertFalse(legacyPolicy.contains("TaskFinalResultInfoRow"))
        assertFalse(legacyPolicy.contains("Regex(\"餐厅"))
        assertTrue(resultPage.contains("AssistantFinalResultPage("))
        assertTrue(resultPage.contains("buildFinalResultPageState("))
        assertFalse(resultPage.contains("data class FinalResultPageState"))
        assertFalse(resultPage.contains("data class FinalResultInfoRow"))
    }

    private fun restaurantSummary(): TaskFinalResultSummaryInput {
        return TaskFinalResultSummaryInput(
            task = "订餐",
            targetLabel = "餐厅",
            target = "北海渔村",
            timeLabel = "时间",
            time = "今晚六点",
            extra = "包间",
            contactLabel = "联系方式",
            contactValue = "18823189131"
        )
    }

    private fun restaurantCallInput(): TaskFinalResultCallInput {
        return TaskFinalResultCallInput(
            name = "北海渔村",
            sub = "AI 通话",
            status = "已完成",
            transcriptTexts = listOf("包间已确认订好")
        )
    }
}
