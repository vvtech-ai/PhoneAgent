package com.vvtech.phone_agent

/** Location-only classification; an unrequested permission is never blocked. */
internal object LocationPermissionPolicy {
    fun status(granted: Boolean, requested: Boolean, canRequestAgain: Boolean): String = when {
        granted -> "granted"
        requested && !canRequestAgain -> "blocked"
        else -> "denied"
    }
}
