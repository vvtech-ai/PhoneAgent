package com.vvtech.phone_agent

internal data class TrustedCallerSurface(
    val token: String, val accountId: String, val phone: String,
    val loginEpoch: Long, val environment: String
) {
    fun report(extra: Map<String, Any?> = emptyMap()): Map<String, Any?> = mapOf(
        "surfaceToken" to token, "accountId" to accountId, "phone" to phone,
        "loginEpoch" to loginEpoch, "environment" to environment
    ) + extra

    companion object {
        fun parse(value: Any?): TrustedCallerSurface? {
            val args = value as? Map<*, *> ?: return null
            val token = args["surfaceToken"] as? String ?: return null
            val account = args["accountId"] as? String ?: return null
            val phone = args["phone"] as? String ?: return null
            val epoch = args["loginEpoch"]
            val environment = args["environment"] as? String ?: return null
            if (!token.matches(Regex("[0-9a-f]{32}")) || account.isBlank() || phone.isBlank() ||
                account.any(Char::isISOControl) || phone.any(Char::isISOControl) ||
                (epoch !is Int && epoch !is Long) || (epoch as Number).toLong() < 0 ||
                environment !in setOf("test", "pro")) return null
            return TrustedCallerSurface(token, account, phone, (epoch as Number).toLong(), environment)
        }
    }
}

internal class TrustedCallerSurfaceRegistry {
    var current: TrustedCallerSurface? = null
        private set
    fun bind(surface: TrustedCallerSurface) { current = surface }
    fun isCurrent(surface: TrustedCallerSurface) = current == surface
    fun release(surface: TrustedCallerSurface): Boolean {
        if (!isCurrent(surface)) return false
        current = null
        return true
    }
}
