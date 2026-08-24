package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.model.UserContextPayload
import kotlinx.coroutines.flow.emptyFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AgentStreamTurnUseCaseSelectedContactTest {
    @Test
    fun streamMapsSelectedContactWithoutChangingMessageOrCommandIdentity() {
        var captured: AgentChatRequest? = null
        val useCase = AgentStreamTurnUseCase { request ->
            captured = request
            emptyFlow()
        }
        val selectedContact = SelectedContactTaskContext.contactDetail(
            name = "张三",
            phone = "13800138000"
        )

        useCase.stream(
            request = AgentStreamTurnUseCaseRequest(
                sessionId = "session-1",
                message = "请帮我联系 张三",
                pendingToolCallId = null,
                channel = "text",
                userId = "user-1",
                initialSkillId = "restaurant_booking",
                initialOpening = "想订哪家餐厅？",
                selectedContact = selectedContact,
                languageCode = "zh-CN",
                responseLanguage = "Simplified Chinese"
            ),
            userContext = UserContextPayload()
        )

        assertEquals("请帮我联系 张三", captured?.message)
        assertEquals(selectedContact, captured?.selectedContact)
        assertEquals("session-1", captured?.sessionId)
        assertEquals("user-1", captured?.userId)
        assertEquals("restaurant_booking", captured?.initialSkillId)
        assertEquals("想订哪家餐厅？", captured?.initialOpening)
        assertEquals(false, captured?.commandId.isNullOrBlank())
        assertEquals(false, captured?.idempotencyKey.isNullOrBlank())
        assertEquals(false, captured?.traceId.isNullOrBlank())
    }

    @Test
    fun streamLeavesSelectedContactNullForOrdinaryTurn() {
        var captured: AgentChatRequest? = null
        val useCase = AgentStreamTurnUseCase { request ->
            captured = request
            emptyFlow()
        }

        useCase.stream(
            request = AgentStreamTurnUseCaseRequest(
                sessionId = "session-2",
                message = "查询天气",
                pendingToolCallId = null,
                channel = "text",
                userId = "user-1",
                languageCode = "zh-CN",
                responseLanguage = "Simplified Chinese"
            ),
            userContext = UserContextPayload()
        )

        assertNull(captured?.selectedContact)
    }
}
