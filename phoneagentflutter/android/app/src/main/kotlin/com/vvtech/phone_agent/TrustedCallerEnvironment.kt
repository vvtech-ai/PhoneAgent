package com.vvtech.phone_agent

/** Registered build identities, shared by process startup and channel validation. */
internal object TrustedCallerEnvironment {
    fun resolve(packageName: String, debuggable: Boolean): String = when (packageName) {
        "com.vvtech.aiassistant.test", "com.vvtech.aiassistant.dev" -> "test"
        "com.vvtech.aiassistant" -> if (debuggable) "test" else "pro"
        else -> "unavailable"
    }
}
