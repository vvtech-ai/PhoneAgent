package com.vvtech.aiassistant.core.model

import com.google.gson.Gson
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentCommandIdentityTest {
    @Test
    fun commandKeyMatchesBackendSharedVector() {
        val identity = AgentCommandIdentity.deterministic(
            sessionId = "session-23065",
            kind = AgentCommandKind.UserTurn,
            commandId = "command-0001",
            traceId = "trace-0001",
        )

        assertEquals("command-0001", identity.commandId)
        assertEquals("trace-0001", identity.traceId)
        assertEquals(
            "conv:v1:command:b0f3ac6af4aabbbc6db710b965435fcd684d931795055448402734aa0804e570",
            identity.idempotencyKey,
        )
    }

    @Test
    fun eachNewIntentGetsFreshIdentity() {
        val first = AgentCommandIdentity.newIntent("session-1", AgentCommandKind.Action)
        val second = AgentCommandIdentity.newIntent("session-1", AgentCommandKind.Action)

        assertNotEquals(first.commandId, second.commandId)
        assertNotEquals(first.idempotencyKey, second.idempotencyKey)
        assertNotEquals(first.traceId, second.traceId)
    }

    @Test
    fun agentRequestSerializesBackendIdentityFieldNamesAtTopLevel() {
        val identity = AgentCommandIdentity.deterministic(
            sessionId = "session-1",
            kind = AgentCommandKind.Action,
            commandId = "command-1",
            traceId = "trace-1",
        )
        val request = AgentChatRequest(
            sessionId = "session-1",
            actionId = "confirm_call",
            commandId = identity.commandId,
            idempotencyKey = identity.idempotencyKey,
            traceId = identity.traceId,
        )

        val json = JsonParser().parse(Gson().toJson(request)).asJsonObject

        assertEquals("command-1", json.get("commandId").asString)
        assertEquals(identity.idempotencyKey, json.get("idempotencyKey").asString)
        assertEquals("trace-1", json.get("traceId").asString)
        assertTrue(json.keySet().containsAll(setOf("sessionId", "actionId", "commandId", "idempotencyKey", "traceId")))
    }
}
