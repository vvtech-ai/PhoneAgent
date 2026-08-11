package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AskQuestionItem
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamActionSubmitStatePolicyTest {
    @Test
    fun optionSelectedClearsOptionsOnly() {
        val state = dirtyState()
        val next = AgentStreamActionSubmitStatePolicy.optionSelected(state, "AI处理中")

        assertSubmitting(next)
        assertNull(next.agentOptions)
        assertSame(state.agentQuestions, next.agentQuestions)
        assertSame(state.agentPermissionRequest, next.agentPermissionRequest)
        assertSame(state.agentDocumentRequest, next.agentDocumentRequest)
        assertTrue(next.agentDocumentImporting)
        assertEquals("tool-old", next.agentPendingToolCallId)
    }

    @Test
    fun answersSubmittedClearsQuestionsAndPendingTool() {
        val state = dirtyState()
        val next = AgentStreamActionSubmitStatePolicy.answersSubmitted(state, "AI处理中")

        assertSubmitting(next)
        assertNull(next.agentQuestions)
        assertNull(next.agentPendingToolCallId)
        assertSame(state.agentOptions, next.agentOptions)
        assertSame(state.agentPermissionRequest, next.agentPermissionRequest)
        assertSame(state.agentDocumentRequest, next.agentDocumentRequest)
    }

    @Test
    fun permissionResultSubmittedClearsPermissionAndPendingTool() {
        val state = dirtyState()
        val next = AgentStreamActionSubmitStatePolicy.permissionResultSubmitted(state, "AI处理中")

        assertSubmitting(next)
        assertNull(next.agentPermissionRequest)
        assertNull(next.agentPendingToolCallId)
        assertSame(state.agentOptions, next.agentOptions)
        assertSame(state.agentQuestions, next.agentQuestions)
        assertSame(state.agentDocumentRequest, next.agentDocumentRequest)
    }

    @Test
    fun documentSubmittedClearsDocumentRequestImportingAndPendingTool() {
        val state = dirtyState()
        val next = AgentStreamActionSubmitStatePolicy.documentSubmitted(state, "AI处理中")

        assertSubmitting(next)
        assertNull(next.agentDocumentRequest)
        assertFalse(next.agentDocumentImporting)
        assertNull(next.agentPendingToolCallId)
        assertSame(state.agentOptions, next.agentOptions)
        assertSame(state.agentQuestions, next.agentQuestions)
        assertSame(state.agentPermissionRequest, next.agentPermissionRequest)
    }

    private fun assertSubmitting(state: Index9AssistantUiState) {
        assertTrue(state.processingTurn)
        assertNull(state.error)
        assertEquals("AI处理中", state.status)
    }

    private fun dirtyState(): Index9AssistantUiState {
        return Index9AssistantUiState(
            processingTurn = false,
            error = "old error",
            status = "old status",
            agentOptions = OptionsPayload("options", listOf(OptionItem(id = "1", label = "one"))),
            agentQuestions = AskQuestionsPayload(
                title = "questions",
                items = listOf(AskQuestionItem(id = "q1", prompt = "question", answerType = "text"))
            ),
            agentPermissionRequest = PermissionRequestPayload(permissionKey = "contacts"),
            agentDocumentRequest = DocumentImportRequestPayload(reason = "upload"),
            agentDocumentImporting = true,
            agentPendingToolCallId = "tool-old"
        )
    }
}
