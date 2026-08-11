package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamMakeCallRequestPolicyTest {
    @Test
    fun planBuildsCallPageSeedAndRecognizedStateForCallSpec() {
        val spec = CallSpecPayload(
            phoneNumber = "010-12345678",
            scene = "restaurant",
            targetName = "北海渔村",
            primaryGoal = "订包间",
            summaryLines = listOf("partySize:4")
        )
        val plan = AgentStreamMakeCallRequestPolicy.plan(
            state = Index9AssistantUiState(
                sceneType = "GENERAL",
                processingTurn = true,
                loading = true,
                error = "旧错误",
                agentPermissionRequest = PermissionRequestPayload(permissionKey = "contacts")
            ),
            currentCallPageSeed = callPageSeed(),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "MAKE_CALL_REQUEST",
                text = null,
                callSpec = spec,
                pendingToolCallId = "tool-1"
            )
        )

        val seed = requireNotNull(plan.nextCallPageSeed)
        assertEquals("北海渔村", seed.name)
        assertEquals("010-12345678", seed.sub)
        assertEquals("准备拨打", seed.status)
        assertTrue(seed.transcript.any { it.text == "已有备注" })
        assertTrue(seed.transcript.any { it.text == "通话任务字段：餐厅：北海渔村" })
        assertTrue(seed.transcript.any { it.text == "通话任务字段：人数：4人" })
        assertEquals(AssistantStage.Recognized, plan.nextState.stage)
        assertFalse(plan.nextState.processingTurn)
        assertFalse(plan.nextState.loading)
        assertNull(plan.nextState.error)
        assertEquals("信息确认完毕，准备拨打电话", plan.nextState.status)
        assertEquals("FOOD_ORDERING", plan.nextState.sceneType)
        assertSame(spec, plan.nextState.agentCallSpec)
        assertNull(plan.nextState.agentQuestions)
        assertNull(plan.nextState.agentPermissionRequest)
        assertNull(plan.nextState.agentDocumentRequest)
        assertEquals("tool-1", plan.nextState.agentPendingToolCallId)
    }

    @Test
    fun planKeepsExistingSeedNameAndUsesSpecPhoneWhenTextFieldsBlank() {
        val plan = AgentStreamMakeCallRequestPolicy.plan(
            state = Index9AssistantUiState(sceneType = "AI_CALL"),
            currentCallPageSeed = callPageSeed(),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "MAKE_CALL_REQUEST",
                text = null,
                callSpec = CallSpecPayload(
                    phoneNumber = "10086",
                    scene = "general",
                    targetName = "",
                    primaryGoal = "",
                    summaryLines = emptyList()
                )
            )
        )

        val seed = requireNotNull(plan.nextCallPageSeed)
        assertEquals("旧联系人", seed.name)
        assertEquals("10086", seed.sub)
        assertTrue(seed.transcript.any { it.text == "通话任务字段：电话：10086" })
    }

    @Test
    fun planReturnsStateOnlyWhenCallSpecMissing() {
        val plan = AgentStreamMakeCallRequestPolicy.plan(
            state = Index9AssistantUiState(sceneType = ""),
            currentCallPageSeed = callPageSeed(),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "MAKE_CALL_REQUEST",
                text = null,
                callSpec = null,
                pendingToolCallId = "tool-empty"
            )
        )

        assertNull(plan.nextCallPageSeed)
        assertEquals("AI_CALL", plan.nextState.sceneType)
        assertNull(plan.nextState.agentCallSpec)
        assertEquals("tool-empty", plan.nextState.agentPendingToolCallId)
    }

    private fun callPageSeed(): CallPageData {
        return CallPageData(
            name = "旧联系人",
            sub = "旧需求",
            status = "旧状态",
            transcript = listOf(TranscriptLine(TranscriptRole.Note, "已有备注"))
        )
    }
}
