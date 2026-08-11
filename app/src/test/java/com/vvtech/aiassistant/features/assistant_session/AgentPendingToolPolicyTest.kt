package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AgentPendingToolPolicyTest {
    @Test
    fun userTurnDoesNotAnswerPermissionRequestWithPlainText() {
        val state = Index9AssistantUiState(
            agentPendingToolCallId = "tool_permission",
            agentPermissionRequest = PermissionRequestPayload(
                permissionKey = "location",
                androidPermission = android.Manifest.permission.ACCESS_FINE_LOCATION
            )
        )

        assertNull(AgentPendingToolPolicy.pendingToolCallIdForUserTurn(state))
    }

    @Test
    fun userTurnKeepsNonPermissionPendingToolId() {
        val state = Index9AssistantUiState(
            agentPendingToolCallId = "tool_question"
        )

        assertEquals("tool_question", AgentPendingToolPolicy.pendingToolCallIdForUserTurn(state))
    }

    @Test
    fun userTurnDoesNotAnswerCallSpecPendingToolWithPlainText() {
        val state = Index9AssistantUiState(
            agentPendingToolCallId = "tool_call",
            agentCallSpec = CallSpecPayload(
                phoneNumber = "13800138000",
                scene = "restaurant",
                targetName = "test",
                primaryGoal = "test",
                summaryLines = listOf("test")
            )
        )

        assertNull(AgentPendingToolPolicy.pendingToolCallIdForUserTurn(state))
    }
}
