package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamInteractiveResponsePolicyTest {
    @Test
    fun askUserVoiceBuildsPromptStepAndClearsStaleChoiceState() {
        val oldOptions = OptionsPayload("旧选项", emptyList())
        val plan = AgentStreamInteractiveResponsePolicy.plan(
            state = Index9AssistantUiState(
                agentOptions = oldOptions,
                agentPendingToolCallId = "old-tool",
                processingTurn = true,
                loading = true
            ),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "ASK_USER",
                text = null,
                questions = AskQuestionsPayload(
                    title = "",
                    items = listOf(AskQuestionItem(id = "people", prompt = "几位用餐", answerType = "text"))
                ),
                pendingToolCallId = "tool-1"
            ),
            voiceMode = true
        )

        requireNotNull(plan)
        assertFalse(plan.nextState.loading)
        assertEquals("几位用餐", plan.voicePrompt)
        assertEquals("再确认几件事\n· 几位用餐", plan.assistantStepText)
        assertEquals(AssistantStage.Clarifying, plan.nextState.stage)
        assertEquals("请语音回答", plan.nextState.status)
        assertEquals(false, plan.nextState.processingTurn)
        assertNull(plan.nextState.agentOptions)
        assertEquals("tool-1", plan.nextState.agentPendingToolCallId)
    }

    @Test
    fun askUserTextStoresQuestionsAndClearsOptions() {
        val questions = AskQuestionsPayload(
            title = "补充信息",
            items = listOf(AskQuestionItem(id = "time", prompt = "几点到店", answerType = "text"))
        )
        val plan = AgentStreamInteractiveResponsePolicy.plan(
            state = Index9AssistantUiState(
                loading = true,
                agentOptions = OptionsPayload("旧选项", emptyList())
            ),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "ASK_USER",
                text = null,
                questions = questions,
                pendingToolCallId = "tool-2"
            ),
            voiceMode = false
        )

        requireNotNull(plan)
        assertFalse(plan.nextState.loading)
        assertNull(plan.voicePrompt)
        assertNull(plan.assistantStepText)
        assertSame(questions, plan.nextState.agentQuestions)
        assertNull(plan.nextState.agentOptions)
        assertEquals("补充信息", plan.nextState.status)
        assertEquals("tool-2", plan.nextState.agentPendingToolCallId)
    }

    @Test
    fun showOptionsVoiceBuildsRestaurantPromptAndStepText() {
        val options = OptionsPayload(
            title = "请选择餐厅",
            items = listOf(
                OptionItem(id = "a", label = "北海渔村", detail = "有包间", address = "深圳湾"),
                OptionItem(id = "b", label = "南海酒楼", detail = "靠窗")
            )
        )
        val plan = AgentStreamInteractiveResponsePolicy.plan(
            state = Index9AssistantUiState(processingTurn = true, loading = true),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "SHOW_OPTIONS",
                text = null,
                options = options,
                pendingToolCallId = "tool-3"
            ),
            voiceMode = true
        )

        requireNotNull(plan)
        assertEquals("请选择餐厅。第一家，北海渔村。第二家，南海酒楼", plan.voicePrompt)
        assertEquals("请选择餐厅\n1. 北海渔村 (有包间 | 深圳湾)\n2. 南海酒楼 (靠窗)", plan.assistantStepText)
        assertEquals("请选择餐厅", plan.nextState.status)
        assertFalse(plan.nextState.processingTurn)
        assertFalse(plan.nextState.loading)
        assertSame(options, plan.nextState.agentOptions)
        assertEquals("tool-3", plan.nextState.agentPendingToolCallId)
    }

    @Test
    fun showOptionsTextStoresOptionsAndClearsQuestions() {
        val options = OptionsPayload(
            title = "请选择联系人",
            items = listOf(OptionItem(id = "a", label = "小明"))
        )
        val plan = AgentStreamInteractiveResponsePolicy.plan(
            state = Index9AssistantUiState(
                loading = true,
                agentQuestions = AskQuestionsPayload("旧问题", emptyList()),
                agentPermissionRequest = PermissionRequestPayload(permissionKey = "contacts")
            ),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "SHOW_OPTIONS",
                text = null,
                options = options,
                pendingToolCallId = "tool-4"
            ),
            voiceMode = false
        )

        requireNotNull(plan)
        assertFalse(plan.nextState.loading)
        assertSame(options, plan.nextState.agentOptions)
        assertNull(plan.nextState.agentQuestions)
        assertNull(plan.nextState.agentPermissionRequest)
        assertEquals("请选择联系人", plan.nextState.status)
        assertEquals("tool-4", plan.nextState.agentPendingToolCallId)
    }

    @Test
    fun permissionAndDocumentRequestsUseFallbackAndClearMutualFields() {
        val permissionPlan = AgentStreamInteractiveResponsePolicy.plan(
            state = Index9AssistantUiState(
                loading = true,
                agentOptions = OptionsPayload("旧选项", emptyList()),
                agentQuestions = AskQuestionsPayload("旧问题", emptyList())
            ),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "REQUEST_PERMISSION",
                text = null,
                permissionRequest = PermissionRequestPayload(permissionKey = "contacts", reason = ""),
                pendingToolCallId = "permission-tool"
            ),
            voiceMode = true
        )
        val documentRequest = DocumentImportRequestPayload(reason = "")
        val documentPlan = AgentStreamInteractiveResponsePolicy.plan(
            state = Index9AssistantUiState(
                loading = true,
                agentOptions = OptionsPayload("旧选项", emptyList()),
                agentQuestions = AskQuestionsPayload("旧问题", emptyList())
            ),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "IMPORT_DOCUMENT_REQUEST",
                text = null,
                documentImportRequest = documentRequest,
                pendingToolCallId = "document-tool"
            ),
            voiceMode = true
        )

        requireNotNull(permissionPlan)
        assertEquals("需要你授权后才能继续", permissionPlan.voicePrompt)
        assertEquals("需要你授权后才能继续", permissionPlan.assistantStepText)
        assertEquals("需要你授权后才能继续", permissionPlan.nextState.status)
        assertNull(permissionPlan.nextState.agentOptions)
        assertNull(permissionPlan.nextState.agentQuestions)
        assertFalse(permissionPlan.nextState.loading)
        assertTrue(permissionPlan.nextState.agentPermissionRequest is PermissionRequestPayload)

        requireNotNull(documentPlan)
        assertEquals("请上传 Markdown 或 TXT 文档", documentPlan.voicePrompt)
        assertEquals("请上传 Markdown 或 TXT 文档", documentPlan.assistantStepText)
        assertEquals("请上传 Markdown 或 TXT 文档", documentPlan.nextState.status)
        assertNull(documentPlan.nextState.agentOptions)
        assertNull(documentPlan.nextState.agentQuestions)
        assertFalse(documentPlan.nextState.loading)
        assertSame(documentRequest, documentPlan.nextState.agentDocumentRequest)
    }
}
