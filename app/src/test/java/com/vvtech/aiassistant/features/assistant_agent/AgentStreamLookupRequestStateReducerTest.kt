package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.LookupDeviceContactsByNamesPayload
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionGroupUi
import com.vvtech.aiassistant.features.assistant.DeviceContactSelectionUiState
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamLookupRequestStateReducerTest {
    @Test
    fun contactLookupRequestBuildsInFlightStateAndClearsMutualFields() {
        val next = AgentStreamLookupRequestStateReducer.contactLookupRequest(
            state = dirtyInteractiveState(),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "LOOKUP_CONTACT_REQUEST",
                text = null,
                pendingToolCallId = "tool-1",
                lookupContactPhone = "13800138000"
            )
        )

        assertEquals(AssistantStage.Clarifying, next.stage)
        assertTrue(next.processingTurn)
        assertNull(next.error)
        assertEquals("AI处理中", next.status)
        assertEquals("tool-1", next.agentPendingToolCallId)
        assertEquals("13800138000", next.agentLookupContactPhone)
        assertTrue(next.agentLookupContactInFlight)
        assertNull(next.agentOptions)
        assertNull(next.agentQuestions)
        assertNull(next.agentPermissionRequest)
        assertNull(next.agentDocumentRequest)
        assertFalse(next.agentDocumentImporting)
    }

    @Test
    fun deviceContactsLookupRequestBuildsInFlightStateAndClearsSelection() {
        val payload = LookupDeviceContactsByNamesPayload(
            names = listOf("小明", "小红"),
            reason = "打电话"
        )
        val next = AgentStreamLookupRequestStateReducer.deviceContactsLookupRequest(
            state = dirtyInteractiveState().copy(agentDeviceContactSelection = deviceSelection()),
            response = AgentChatResponse(
                sessionId = "s1",
                type = "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST",
                text = null,
                pendingToolCallId = "tool-2",
                lookupDeviceContactsByNames = payload
            )
        )

        requireNotNull(next)
        assertEquals(AssistantStage.Clarifying, next.stage)
        assertTrue(next.processingTurn)
        assertEquals("AI处理中", next.status)
        assertEquals("tool-2", next.agentPendingToolCallId)
        assertSame(payload, next.agentLookupDeviceContactsRequest)
        assertTrue(next.agentLookupDeviceContactsInFlight)
        assertNull(next.agentDeviceContactSelection)
        assertNull(next.agentOptions)
        assertNull(next.agentQuestions)
        assertNull(next.agentPermissionRequest)
        assertNull(next.agentDocumentRequest)
        assertFalse(next.agentDocumentImporting)
    }

    @Test
    fun deviceContactsLookupRequestSkipsInvalidPayload() {
        val base = Index9AssistantUiState()

        assertNull(
            AgentStreamLookupRequestStateReducer.deviceContactsLookupRequest(
                state = base,
                response = AgentChatResponse(
                    sessionId = "s1",
                    type = "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST",
                    text = null,
                    pendingToolCallId = "tool-1",
                    lookupDeviceContactsByNames = null
                )
            )
        )
        assertNull(
            AgentStreamLookupRequestStateReducer.deviceContactsLookupRequest(
                state = base,
                response = AgentChatResponse(
                    sessionId = "s1",
                    type = "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST",
                    text = null,
                    pendingToolCallId = "tool-1",
                    lookupDeviceContactsByNames = LookupDeviceContactsByNamesPayload(names = emptyList())
                )
            )
        )
        assertNull(
            AgentStreamLookupRequestStateReducer.deviceContactsLookupRequest(
                state = base,
                response = AgentChatResponse(
                    sessionId = "s1",
                    type = "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST",
                    text = null,
                    pendingToolCallId = "",
                    lookupDeviceContactsByNames = LookupDeviceContactsByNamesPayload(names = listOf("小明"))
                )
            )
        )
    }

    private fun dirtyInteractiveState(): Index9AssistantUiState {
        return Index9AssistantUiState(
            processingTurn = false,
            error = "旧错误",
            status = "旧状态",
            agentOptions = OptionsPayload("旧选项", listOf(OptionItem(id = "a", label = "A"))),
            agentQuestions = AskQuestionsPayload("旧问题", emptyList()),
            agentPermissionRequest = PermissionRequestPayload(permissionKey = "contacts"),
            agentDocumentRequest = DocumentImportRequestPayload(reason = "旧文档"),
            agentDocumentImporting = true
        )
    }

    private fun deviceSelection(): DeviceContactSelectionUiState {
        return DeviceContactSelectionUiState(
            pendingToolCallId = "old-tool",
            groups = listOf(DeviceContactSelectionGroupUi(name = "小明", candidates = emptyList()))
        )
    }
}
