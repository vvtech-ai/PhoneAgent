package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.StatusStyle
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionHistoryPolicyTest {
    @Test
    fun manualHangupPlanKeepsHumanTakeoverHistory() {
        val plan = taskCallSessionManualHangupHistoryPlan(
            taskId = "task-1",
            callId = "call-1",
            currentTitle = "",
            sceneType = "FOOD_ORDERING",
            currentCallUiMode = CallUiMode.Human,
            responseStatusMessage = "",
            fallbackStatus = "正在挂断通话..."
        )

        assertEquals("task-1", plan.taskId)
        assertEquals("call-1", plan.callId)
        assertEquals("订餐任务", plan.title)
        assertEquals("人工接管", plan.status)
        assertEquals(StatusStyle.Success, plan.style)
        assertEquals("正在挂断通话...", plan.metaDetail)
        assertTrue(plan.finalState)
    }

    @Test
    fun manualHangupPlanKeepsAiAbortFailureHistory() {
        val plan = taskCallSessionManualHangupHistoryPlan(
            taskId = "task-1",
            callId = "call-1",
            currentTitle = "北海渔村",
            sceneType = "FOOD_ORDERING",
            currentCallUiMode = CallUiMode.Ai,
            responseStatusMessage = "用户已挂断",
            fallbackStatus = "正在挂断通话..."
        )

        assertEquals("北海渔村", plan.title)
        assertEquals("手动中止", plan.status)
        assertEquals(StatusStyle.Failure, plan.style)
        assertEquals("用户已挂断", plan.metaDetail)
        assertTrue(plan.finalState)
    }

    @Test
    fun activePlanKeepsHumanAndAiRunningSemantics() {
        val humanPlan = taskCallSessionActiveHistoryPlan(
            response = response(
                handoffMode = "HUMAN_ACTIVE",
                callState = "CONNECTED",
                statusMessage = ""
            ),
            currentTitle = "当前标题",
            facts = facts(humanMode = true, terminalCallState = false)
        )
        val aiRunningPlan = taskCallSessionActiveHistoryPlan(
            response = response(
                handoffMode = "AI_ACTIVE",
                callState = "CONNECTED",
                targetName = "",
                phoneNumber = "0755-12345678",
                statusMessage = ""
            ),
            currentTitle = "当前标题",
            facts = facts(humanMode = false, terminalCallState = false)
        )
        val terminalPlan = taskCallSessionActiveHistoryPlan(
            response = response(callState = "ENDED"),
            currentTitle = "当前标题",
            facts = facts(humanMode = false, terminalCallState = true)
        )

        assertEquals("人工接管", humanPlan?.status)
        assertEquals(StatusStyle.Success, humanPlan?.style)
        assertEquals("0755-86966889", humanPlan?.metaDetail)
        assertTrue(humanPlan?.finalState == true)

        assertEquals("AI代打中", aiRunningPlan?.status)
        assertEquals(StatusStyle.Success, aiRunningPlan?.style)
        assertEquals("当前标题", aiRunningPlan?.title)
        assertEquals("0755-12345678", aiRunningPlan?.metaDetail)
        assertFalse(aiRunningPlan?.finalState ?: true)

        assertNull(terminalPlan)
    }

    @Test
    fun terminalPlanConsumesDisplayPlanAndKeepsFallbacks() {
        val plan = taskCallSessionTerminalHistoryPlan(
            response = response(
                sceneType = "FOOD_ORDERING",
                targetName = "",
                phoneNumber = "",
                statusMessage = ""
            ),
            currentTitle = "",
            currentCallPageStatus = "通话已结束",
            terminalPlan = CallSessionTerminalDisplayPlan(
                historyStatus = "任务完成",
                historyStyle = StatusStyle.Success,
                taskStatus = "COMPLETED",
                statusText = "任务完成"
            )
        )

        assertEquals("订餐任务", plan.title)
        assertEquals("任务完成", plan.status)
        assertEquals(StatusStyle.Success, plan.style)
        assertEquals("通话已结束", plan.metaDetail)
        assertTrue(plan.finalState)
    }

    @Test
    fun callRuntimeDoesNotRestoreDeletedLocalHistoryWrites() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionStatusApplyController.kt")
                .readText(Charsets.UTF_8)
        val terminalController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionTerminalStatusController.kt")
                .readText(Charsets.UTF_8)
        val userCommandController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionUserCommandController.kt")
                .readText(Charsets.UTF_8)
        val policy =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionHistoryPolicy.kt")
                .readText(Charsets.UTF_8)

        assertFalse(handler.contains("taskCallSessionManualHangupHistoryPlan("))
        assertFalse(userCommandController.contains("taskCallSessionManualHangupHistoryPlan("))
        assertFalse(handler.contains("taskCallSessionActiveHistoryPlan("))
        assertFalse(handler.contains("taskCallSessionTerminalHistoryPlan("))
        assertFalse(controller.contains("taskCallSessionActiveHistoryPlan("))
        assertFalse(controller.contains("taskCallSessionTerminalHistoryPlan("))
        assertFalse(terminalController.contains("taskCallSessionTerminalHistoryPlan("))
        assertFalse(handler.contains("upsertLocalCallHistory"))
        assertFalse(controller.contains("upsertLocalCallHistory"))
        assertFalse(terminalController.contains("upsertLocalCallHistory"))
        assertFalse(userCommandController.contains("upsertLocalCallHistory"))
        assertFalse(handler.contains("val historyStatus = if (state.callUiMode == CallUiMode.Human)"))
        assertFalse(handler.contains("status = \"AI代打中\""))
        assertFalse(handler.contains("status = \"手动中止\""))
        assertFalse(handler.contains("style = StatusStyle"))
        assertFalse(handler.contains("buildCallHistoryMetaDetail("))
        assertFalse(handler.contains("sceneLabel(response.sceneType)"))

        assertTrue(policy.contains("status = \"AI代打中\""))
        assertTrue(policy.contains("status = \"人工接管\""))
        assertTrue(policy.contains("status = historyStatus"))
        assertTrue(policy.contains("buildTaskCallHistoryMetaDetail("))
    }

    private fun facts(
        humanMode: Boolean,
        terminalCallState: Boolean
    ): TaskCallSessionStatusFacts {
        return TaskCallSessionStatusFacts(
            humanMode = humanMode,
            humanRequested = false,
            terminalCallState = terminalCallState,
            protectTakeoverState = false,
            note = null,
            shouldStartTakeoverAudio = false,
            shouldStopTakeoverAudio = false
        )
    }

    private fun response(
        taskId: String = "task-1",
        callId: String = "call-1",
        sceneType: String = "FOOD_ORDERING",
        targetName: String = "北海渔村",
        phoneNumber: String = "0755-86966889",
        callState: String = "CONNECTED",
        handoffMode: String = "AI_ACTIVE",
        statusMessage: String = "通话进行中"
    ): CallSessionStatusResponse {
        return CallSessionStatusResponse(
            callId = callId,
            taskId = taskId,
            sceneType = sceneType,
            targetName = targetName,
            phoneNumber = phoneNumber,
            callState = callState,
            handoffMode = handoffMode,
            backendCallEnabled = true,
            handoffSupported = true,
            appRtcRequired = false,
            dialogueDetail = "",
            statusMessage = statusMessage,
            updatedAt = "2026-06-11T10:00:00"
        )
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
