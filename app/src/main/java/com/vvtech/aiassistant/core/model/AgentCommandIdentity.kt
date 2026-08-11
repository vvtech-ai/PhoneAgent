package com.vvtech.aiassistant.core.model

import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.UUID

enum class AgentCommandKind(val wireName: String) {
    UserTurn("user_turn"),
    Action("action"),
}

/** Stable identity for one user intent. Reuse the instance for every transport retry. */
data class AgentCommandIdentity(
    val commandId: String,
    val idempotencyKey: String,
    val traceId: String,
) {
    init {
        require(commandId.isNotBlank()) { "commandId is required" }
        require(idempotencyKey.isNotBlank()) { "idempotencyKey is required" }
        require(traceId.isNotBlank()) { "traceId is required" }
    }

    companion object {
        fun newIntent(sessionId: String, kind: AgentCommandKind): AgentCommandIdentity {
            val commandId = UUID.randomUUID().toString()
            return deterministic(
                sessionId = sessionId,
                kind = kind,
                commandId = commandId,
                traceId = UUID.randomUUID().toString(),
            )
        }

        fun deterministic(
            sessionId: String,
            kind: AgentCommandKind,
            commandId: String,
            traceId: String,
        ): AgentCommandIdentity {
            require(sessionId.isNotBlank()) { "sessionId is required" }
            require(commandId.isNotBlank()) { "commandId is required" }
            require(traceId.isNotBlank()) { "traceId is required" }
            return AgentCommandIdentity(
                commandId = commandId,
                idempotencyKey = commandKey(sessionId, kind, commandId),
                traceId = traceId,
            )
        }

        private fun commandKey(
            sessionId: String,
            kind: AgentCommandKind,
            commandId: String,
        ): String {
            val digest = MessageDigest.getInstance("SHA-256")
            listOf("command", sessionId, kind.wireName, commandId).forEach { value ->
                val bytes = value.toByteArray(StandardCharsets.UTF_8)
                digest.update(ByteBuffer.allocate(Int.SIZE_BYTES).putInt(bytes.size).array())
                digest.update(bytes)
            }
            val hash = digest.digest().joinToString(separator = "") { byte ->
                "%02x".format(byte.toInt() and 0xff)
            }
            return "conv:v1:command:$hash"
        }
    }
}
