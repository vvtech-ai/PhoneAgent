package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamConfirmCallLaunchPolicyTest {
    @Test
    fun manualConfirmBuildsCallSeedEchoAndNextState() {
        val spec = callSpec()
        val result = CallResultPayload("COMPLETED", "旧结果", "旧详情")
        val seed = callPageSeed()

        val plan = AgentStreamConfirmCallLaunchPolicy.plan(
            AgentStreamConfirmCallLaunchInput(
                state = dirtyState(spec = spec, result = result),
                latestCallPageSeed = seed,
                sessionId = "session-1",
                auto = false,
                dialingStatusText = "正在拨打电话...",
                manualEchoText = "已确认拨打"
            )
        )

        assertEquals("已确认拨打", plan.userEchoText)
        assertEquals("正在拨打电话...", plan.callPageSeed.status)
        assertTrue(plan.callPageSeed.transcript.any { it.text == "已有备注" })
        assertFalse(plan.callPageSeed.transcript.any { it.text == "旧助手转写" })
        assertTrue(plan.callPageSeed.transcript.any { it.text == "通话任务字段：餐厅：北海渔村" })
        assertTrue(plan.callPageSeed.transcript.any { it.text == "通话任务字段：电话：010-12345678" })
        assertTrue(plan.callPageSeed.transcript.any { it.text == "通话任务字段：包房：需要包房" })

        val next = plan.nextState
        assertEquals(AssistantStage.Recognized, next.stage)
        assertTrue(next.processingTurn)
        assertNull(next.error)
        assertEquals("正在拨打电话...", next.status)
        assertEquals("session-1", next.taskId)
        assertEquals(CallUiMode.Ai, next.callUiMode)
        assertEquals(plan.callPageSeed, next.callPageData)
        assertTrue(next.showAiCallPage)
        assertFalse(next.handoffInFlight)
        assertNull(next.agentCallSpec)
        assertNull(next.agentCallResult)
    }

    @Test
    fun autoConfirmSkipsUserEchoButKeepsLaunchState() {
        val plan = AgentStreamConfirmCallLaunchPolicy.plan(
            AgentStreamConfirmCallLaunchInput(
                state = dirtyState(spec = callSpec(), result = null),
                latestCallPageSeed = callPageSeed(),
                sessionId = "session-auto",
                auto = true,
                dialingStatusText = "正在拨打电话...",
                manualEchoText = "已确认拨打"
            )
        )

        assertNull(plan.userEchoText)
        assertEquals("session-auto", plan.nextState.taskId)
        assertEquals(CallUiMode.Ai, plan.nextState.callUiMode)
        assertTrue(plan.nextState.showAiCallPage)
        assertSame(plan.callPageSeed, plan.nextState.callPageData)
        assertTrue(plan.callPageSeed.transcript.any { it.text == "通话任务字段：需求：订包间" })
    }

    private fun dirtyState(
        spec: CallSpecPayload,
        result: CallResultPayload?
    ): Index9AssistantUiState {
        return Index9AssistantUiState(
            stage = AssistantStage.Clarifying,
            processingTurn = false,
            error = "旧错误",
            status = "旧状态",
            taskId = "old-session",
            callUiMode = CallUiMode.Human,
            callPageData = CallPageData("旧页面", "旧需求", "旧状态", emptyList()),
            showAiCallPage = false,
            handoffInFlight = true,
            agentCallSpec = spec,
            agentCallResult = result
        )
    }

    private fun callPageSeed(): CallPageData {
        return CallPageData(
            name = "北海渔村",
            sub = "订包间",
            status = "准备拨打",
            transcript = listOf(
                TranscriptLine(TranscriptRole.Note, "已有备注"),
                TranscriptLine(TranscriptRole.Assistant, "旧助手转写")
            )
        )
    }

    private fun callSpec(): CallSpecPayload {
        return CallSpecPayload(
            phoneNumber = "010-12345678",
            scene = "restaurant",
            targetName = "北海渔村",
            primaryGoal = "订包间",
            summaryLines = listOf("partySize:4", "needPrivateRoom:true")
        )
    }
}
