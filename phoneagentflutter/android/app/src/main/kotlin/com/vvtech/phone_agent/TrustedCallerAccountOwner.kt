package com.vvtech.phone_agent

import java.security.MessageDigest

internal data class TrustedCallerAccountOwner(
    val accountId: String, val phone: String, val loginEpoch: Long, val environment: String
) {
    fun matches(surface: TrustedCallerSurface) = accountId == surface.accountId &&
        phone == surface.phone && loginEpoch == surface.loginEpoch && environment == surface.environment

    fun storageKey(): String = MessageDigest.getInstance("SHA-256")
        .digest(listOf(environment, accountId, phone, loginEpoch.toString()).joinToString("\u0000").toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    companion object {
        fun parse(value: Any?, environment: String): TrustedCallerAccountOwner? {
            val fields = value as? Map<*, *> ?: return null
            if (fields.keys != setOf("accountId", "phone", "loginEpoch") || environment !in setOf("test", "pro")) return null
            val account = fields["accountId"] as? String ?: return null
            val phone = fields["phone"] as? String ?: return null
            val epoch = fields["loginEpoch"]
            if (account.isBlank() || phone.isBlank() || account.any(Char::isISOControl) || phone.any(Char::isISOControl) ||
                (epoch !is Int && epoch !is Long) || (epoch as Number).toLong() < 0) return null
            return TrustedCallerAccountOwner(account, phone, epoch.toLong(), environment)
        }
    }
}
