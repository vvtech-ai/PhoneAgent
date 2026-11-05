package com.vvtech.phone_agent

import com.vvtech.aiassistant.BuildConfig

/** Values are injected from the root private local.properties during the build. */
object TrustedCallerLocalCredentials {
    @JvmStatic
    fun read(environment: String): Map<String, String>? {
        if (environment !in setOf("test", "pro") ||
            environment != BuildConfig.TRUSTED_CALLER_ENVIRONMENT
        ) return null
        val key = BuildConfig.TRUSTED_CALLER_APP_KEY
        val secret = BuildConfig.TRUSTED_CALLER_APP_SECRET
        if (key.isBlank() || secret.isBlank()) return null
        return mapOf("appKey" to key, "appSecret" to secret)
    }
}
