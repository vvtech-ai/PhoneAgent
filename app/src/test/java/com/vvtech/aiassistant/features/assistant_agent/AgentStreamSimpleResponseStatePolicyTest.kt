package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamSimpleResponseStatePolicyTest {
    @Test
    fun recoveryConfirmationClassifiesResponseTypes() {
        assertEquals(
            AgentStreamRecoveryConfirmation.PromoteRunning,
            AgentStreamSimpleResponseStatePolicy.recoveryConfirmation("TEXT_REPLY")
        )
        assertEquals(
            AgentStreamRecoveryConfirmation.PromoteRunning,
            AgentStreamSimpleResponseStatePolicy.recoveryConfirmation("ASK_USER")
        )
        assertEquals(
            AgentStreamRecoveryConfirmation.PromoteRunning,
            AgentStreamSimpleResponseStatePolicy.recoveryConfirmation("LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST")
        )
        assertEquals(
            AgentStreamRecoveryConfirmation.TerminalNoPromote,
            AgentStreamSimpleResponseStatePolicy.recoveryConfirmation("CALL_RESULT")
        )
        assertEquals(
            AgentStreamRecoveryConfirmation.TerminalNoPromote,
            AgentStreamSimpleResponseStatePolicy.recoveryConfirmation("BATCH_CALL_RESULT")
        )
        assertEquals(
            AgentStreamRecoveryConfirmation.None,
            AgentStreamSimpleResponseStatePolicy.recoveryConfirmation("UNKNOWN")
        )
    }

    @Test
    fun textReplyClearsInteractiveRequestState() {
        val next = AgentStreamSimpleResponseStatePolicy.textReply(
            dirtyState(),
            statusText = "AI已回复"
        )

        assertEquals(AssistantStage.Clarifying, next.stage)
        assertFalse(next.processingTurn)
        assertFalse(next.loading)
        assertNull(next.error)
        assertEquals("AI已回复", next.status)
        assertNull(next.agentPermissionRequest)
        assertNull(next.agentDocumentRequest)
        assertFalse(next.agentDocumentImporting)
        assertNull(next.agentPendingToolCallId)
    }

    @Test
    fun executionErrorClearsProcessingAndDocumentImporting() {
        val next = AgentStreamSimpleResponseStatePolicy.executionError(
            state = dirtyState(),
            errorText = "执行失败",
            statusText = "出错了"
        )

        assertFalse(next.processingTurn)
        assertEquals("执行失败", next.error)
        assertEquals("出错了", next.status)
        assertFalse(next.agentDocumentImporting)
    }

    @Test
    fun voiceRecoveryClearsProcessingAndKeepsRecoveryStatus() {
        val next = AgentStreamSimpleResponseStatePolicy.voiceRecovery(
            state = dirtyState(),
            statusText = "我继续听你说",
            resetManualPause = true
        )

        assertFalse(next.processingTurn)
        assertNull(next.error)
        assertEquals("我继续听你说", next.status)
        assertFalse(next.voiceManuallyPaused)
        assertFalse(next.agentDocumentImporting)
    }

    @Test
    fun unknownErrorTextIncludesResponseType() {
        assertEquals(
            "未知响应类型: NEW_TYPE",
            AgentStreamSimpleResponseStatePolicy.unknownErrorText("NEW_TYPE")
        )
    }

    private fun dirtyState(): Index9AssistantUiState {
        return Index9AssistantUiState(
            stage = AssistantStage.Recognized,
            processingTurn = true,
            loading = true,
            error = "旧错误",
            status = "旧状态",
            voiceManuallyPaused = true,
            agentPermissionRequest = PermissionRequestPayload(permissionKey = "contacts"),
            agentDocumentRequest = DocumentImportRequestPayload(reason = "upload"),
            agentDocumentImporting = true,
            agentPendingToolCallId = "tool-1"
        )
    }
}
