package com.vvtech.phone_agent

import java.security.MessageDigest

/** Exact v65 key derivation; identifiers are never used as paths. */
internal object LegacyRatingDraftKey {
    const val MAX_BYTES = 64 * 1024

    fun key(account: String, taskType: String, taskId: String): String {
        require(account != "guest" && account.matches(Regex("[A-Za-z0-9_.-]+")))
        listOf(account, taskType, taskId).forEach { value ->
            require(value.isNotBlank() && value.length <= 256 &&
                value.none { it.code < 32 || it.code == 127 })
        }
        val input = listOf(account, taskType, taskId).joinToString("\u0000")
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return "task_rating_draft_$digest"
    }

    fun bounded(raw: String?): String? {
        require(raw == null || (raw.length <= MAX_BYTES &&
            raw.toByteArray(Charsets.UTF_8).size <= MAX_BYTES))
        return raw
    }
}
