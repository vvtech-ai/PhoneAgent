package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamNormalActionEntryHandlerTest {
    @Test
    fun optionEntryBuildsSubmitInputAndDelegatesSubmitHandler() {
        val recorder = ActionSubmitRecorder(
            Index9AssistantUiState(
                agentOptions = OptionsPayload(
                    title = "请选择餐厅",
                    items = listOf(OptionItem(id = "a", label = "北海渔村", detail = "包间优先", phone = "123"))
                )
            )
        )
        val handler = recorder.entryHandler()

        handler.onOptionSelect("a")

        val request = recorder.singleRequest()
        assertEquals("select_option", request.actionId)
        assertEquals("agent_select_option", request.contextReason)
        assertEquals("select_option", request.logAction)
        assertEquals("选择失败", request.failureMessage)
        assertEquals("a", request.actionPayload.orEmpty()["optionId"])
        assertTrue(recorder.state.processingTurn)
        assertNull(recorder.state.agentOptions)
        assertEquals("AI处理中", recorder.state.status)
        assertEquals(1, recorder.echoes.size)
    }

    @Test
    fun answerEntryBuildsSubmitInputAndClearsPendingQuestions() {
        val recorder = ActionSubmitRecorder(
            Index9AssistantUiState(
                agentQuestions = AskQuestionsPayload(
                    title = "补充信息",
                    items = listOf(AskQuestionItem(id = "confirm", prompt = "是否需要包间", answerType = "confirm"))
                ),
                agentPendingToolCallId = "tool-1"
            )
        )
        val handler = recorder.entryHandler()

        handler.onAnswerSubmit(mapOf("confirm" to "yes"))

        val request = recorder.singleRequest()
        assertEquals("answer_questions", request.actionId)
        assertEquals("agent_answer_questions", request.contextReason)
        assertEquals("answer_questions", request.logAction)
        assertEquals("提交失败", request.failureMessage)
        assertEquals(mapOf("confirm" to "yes"), request.actionPayload.orEmpty()["answers"])
        assertTrue(recorder.state.processingTurn)
        assertNull(recorder.state.agentQuestions)
        assertNull(recorder.state.agentPendingToolCallId)
    }

    @Test
    fun permissionEntryBuildsSubmitInputAndClearsPermissionState() {
        val recorder = ActionSubmitRecorder(Index9AssistantUiState(agentPendingToolCallId = "tool-1"))
        val handler = recorder.entryHandler()

        handler.onPermissionResult(
            permissionKey = "contacts",
            androidPermission = "android.permission.READ_CONTACTS",
            status = "",
            granted = false,
            message = "denied"
        )

        val request = recorder.singleRequest()
        assertEquals("permission_result", request.actionId)
        assertEquals("agent_permission_result", request.contextReason)
        assertEquals("permission_result", request.logAction)
        assertEquals("权限结果提交失败", request.failureMessage)
        assertEquals("DENIED", request.actionPayload.orEmpty()["status"])
        assertEquals(false, request.actionPayload.orEmpty()["granted"])
        assertTrue(recorder.state.processingTurn)
        assertNull(recorder.state.agentPendingToolCallId)
        assertTrue(recorder.echoes.isEmpty())
    }

    @Test
    fun documentEntryKeepsFailureRecoveryCallback() {
        val recorder = ActionSubmitRecorder(
            Index9AssistantUiState(
                agentDocumentImporting = true,
                agentPendingToolCallId = "tool-1"
            )
        )
        val handler = recorder.entryHandler()

        handler.onDocumentSubmit(
            DocumentParseResult(
                status = "",
                fileName = "menu.txt",
                mimeType = "text/plain",
                charCount = 12,
                truncated = false,
                content = "hello",
                message = ""
            )
        )

        val request = recorder.singleRequest()
        assertEquals("submit_document", request.actionId)
        assertEquals("agent_submit_document", request.contextReason)
        assertEquals("submit_document", request.logAction)
        assertEquals("文档结果提交失败", request.failureMessage)
        assertEquals("PARSE_FAILED", request.actionPayload.orEmpty()["status"])
        assertFalse(recorder.state.agentDocumentImporting)

        recorder.state = recorder.state.copy(agentDocumentImporting = true)
        recorder.beforeRecover?.invoke()
        assertFalse(recorder.state.agentDocumentImporting)
    }

    @Test
    fun missingSessionSkipsSubmit() {
        val recorder = ActionSubmitRecorder(Index9AssistantUiState(), sessionId = null)
        val handler = recorder.entryHandler()

        handler.onOptionSelect("a")

        assertTrue(recorder.requests.isEmpty())
        assertTrue(recorder.echoes.isEmpty())
    }

    @Test
    fun agentStreamHandlerDelegatesNormalActionEntries() {
        val host = File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
            .readText()
        val actionGraph =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText()
        val entryHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamNormalActionEntryHandler.kt")
                .readText()

        assertTrue(host.contains("actionGraph.onAgentOptionSelect(optionId)"))
        assertTrue(host.contains("actionGraph.onAgentAnswerSubmit(answers)"))
        assertTrue(host.contains("actionGraph.onAgentPermissionResult("))
        assertTrue(host.contains("actionGraph.onAgentDocumentSubmit(result)"))
        assertTrue(actionGraph.contains("AgentStreamNormalActionEntryHandler("))
        assertTrue(actionGraph.contains("normalActionEntryHandler.onOptionSelect(optionId)"))
        assertTrue(actionGraph.contains("normalActionEntryHandler.onAnswerSubmit(answers)"))
        assertTrue(actionGraph.contains("normalActionEntryHandler.onPermissionResult("))
        assertTrue(actionGraph.contains("normalActionEntryHandler.onDocumentSubmit(result)"))
        assertFalse(host.contains("AgentStreamUserActionPolicy.optionSelection("))
        assertFalse(host.contains("AgentStreamUserActionPolicy.answerSubmit("))
        assertFalse(host.contains("AgentStreamUserActionPolicy.permissionResult("))
        assertFalse(host.contains("AgentStreamUserActionPolicy.documentSubmit("))
        assertFalse(host.contains("AgentStreamNormalActionSubmitInput("))

        assertTrue(entryHandler.contains("AgentStreamUserActionPolicy.optionSelection("))
        assertTrue(entryHandler.contains("AgentStreamUserActionPolicy.answerSubmit("))
        assertTrue(entryHandler.contains("AgentStreamUserActionPolicy.permissionResult("))
        assertTrue(entryHandler.contains("AgentStreamUserActionPolicy.documentSubmit("))
        assertTrue(entryHandler.contains("AgentStreamNormalActionSubmitInput("))
        assertTrue(entryHandler.contains("agentDocumentImporting = false"))
    }

    private class ActionSubmitRecorder(
        var state: Index9AssistantUiState,
        private val sessionId: String? = "session-1"
    ) {
        val echoes = mutableListOf<String>()
        val requests = mutableListOf<AgentStreamActionSubmitRequest>()
        var beforeRecover: (() -> Unit)? = null
        private var placeholderIndex = 0

        fun entryHandler(): AgentStreamNormalActionEntryHandler {
            val submitHandler = AgentStreamNormalActionSubmitHandler(
                appendUserStep = { echoes += it },
                updateUiState = { reducer -> state = reducer(state) },
                appendAssistantPlaceholder = { ++placeholderIndex },
                submitAction = { request, recover ->
                    requests += request
                    beforeRecover = recover
                },
                channelProvider = { "text" },
                userIdProvider = { "user-1" }
            )
            return AgentStreamNormalActionEntryHandler(
                sessionIdProvider = { sessionId },
                stateProvider = { state },
                updateUiState = { reducer -> state = reducer(state) },
                submitHandler = submitHandler
            )
        }

        fun singleRequest(): AgentStreamActionSubmitRequest {
            assertEquals(1, requests.size)
            return requests.single()
        }
    }
}
