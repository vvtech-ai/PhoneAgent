package com.vvtech.phone_agent

/** Build-injected private configuration; credentials never cross the Flutter channel. */
internal object TrustedCallerConfiguration {
    fun read(environment: String): Map<String, String>? = try {
        val type = Class.forName("com.vvtech.phone_agent.TrustedCallerLocalCredentials")
        val raw = type.getMethod("read", String::class.java).invoke(null, environment) as? Map<*, *>
        val key = raw?.get("appKey") as? String
        val secret = raw?.get("appSecret") as? String
        if (key.isNullOrBlank() || secret.isNullOrBlank()) null
        else mapOf("appKey" to key, "appSecret" to secret)
    } catch (_: ReflectiveOperationException) {
        null
    } catch (_: LinkageError) {
        null
    }
}
