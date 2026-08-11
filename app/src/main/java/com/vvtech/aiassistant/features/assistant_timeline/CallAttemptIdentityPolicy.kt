package com.vvtech.aiassistant.features.assistant_timeline

/** Resolves a repeatable attempt identity without depending on wall-clock time. */
object CallAttemptIdentityPolicy {
    fun resolve(input: CallAttemptIdentityInput): CallAttemptIdentity {
        firstNonBlank(input.callId)?.let { return identity(CallAttemptIdentitySource.CallId, it) }
        firstNonBlank(input.callSessionCallId)?.let {
            return identity(CallAttemptIdentitySource.CallSessionCallId, it)
        }
        firstNonBlank(input.toolCallId)?.let { return identity(CallAttemptIdentitySource.ToolCallId, it) }
        firstNonBlank(input.toolResultId)?.let { return identity(CallAttemptIdentitySource.ToolResultId, it) }

        val toolName = input.toolName?.trim().orEmpty().ifBlank { "unknown-tool" }
        input.messageIndex?.let { index ->
            return CallAttemptIdentity(
                value = "message:$index:tool:$toolName",
                source = CallAttemptIdentitySource.MessageIndex
            )
        }
        require(input.fallbackAnchor.isNotBlank()) {
            "A deterministic fallbackAnchor is required when call and tool identifiers are absent."
        }
        return CallAttemptIdentity(
            value = "fallback:${input.fallbackAnchor.trim()}:tool:$toolName",
            source = CallAttemptIdentitySource.FallbackAnchor
        )
    }

    private fun identity(source: CallAttemptIdentitySource, rawId: String): CallAttemptIdentity {
        return CallAttemptIdentity(value = "${source.prefix}:${rawId.trim()}", source = source)
    }

    private fun firstNonBlank(value: String?): String? = value?.trim()?.takeIf { it.isNotEmpty() }
}

data class CallAttemptIdentityInput(
    val callId: String? = null,
    val callSessionCallId: String? = null,
    val toolCallId: String? = null,
    val toolResultId: String? = null,
    val messageIndex: Int? = null,
    val toolName: String? = null,
    val fallbackAnchor: String = ""
)

data class CallAttemptIdentity(
    val value: String,
    val source: CallAttemptIdentitySource
)

enum class CallAttemptIdentitySource(val prefix: String) {
    CallId("call"),
    CallSessionCallId("session-call"),
    ToolCallId("tool-call"),
    ToolResultId("tool-result"),
    MessageIndex("message"),
    FallbackAnchor("fallback")
}
