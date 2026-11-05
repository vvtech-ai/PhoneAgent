package com.vvtech.phone_agent.diagnostics

import java.util.UUID

/** Never inspect a throwable's message, stack, class name or thread name. */
data class CrashSummary(
    val id: String = UUID.randomUUID().toString(),
    val time: Long = System.currentTimeMillis(),
    val mainThread: Boolean,
    val kind: String,
) {
    init {
        require(ID.matches(id) && time in 946684800000L..4102444800000L)
        require(kind in KINDS)
    }

    fun payload(scope: String): Map<String, Any> = mapOf(
        "scope" to scope, "id" to id, "time" to time,
        "mainThread" to mainThread, "kind" to kind,
    )

    companion object {
        val ID = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
        val SCOPE = Regex("[0-9a-f]{64}")
        val KINDS = setOf("argument", "state", "assertion", "other")
        fun classify(error: Throwable): String = when (error) {
            is IllegalArgumentException -> "argument"
            is IllegalStateException -> "state"
            is AssertionError -> "assertion"
            else -> "other"
        }
    }
}
