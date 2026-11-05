package com.vvtech.phone_agent

/** Transports only a safe code; memo and the signed provider result stay native. */
internal object AlipayResultStatus {
    fun project(result: Map<String, String>?): Map<String, String> {
        val code = result?.get("resultStatus")
        return if (code != null && code.matches(Regex("[0-9]{4}"))) {
            mapOf("nativeResultStatus" to code)
        } else emptyMap()
    }
}
