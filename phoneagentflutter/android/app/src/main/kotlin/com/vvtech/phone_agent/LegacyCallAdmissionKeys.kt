package com.vvtech.phone_agent

/** Only digest-shaped keys under one fixed preference prefix are accepted. */
internal object LegacyCallAdmissionKeys {
    fun validate(digests: List<*>): List<String> {
        require(digests.isNotEmpty() && digests.size <= 1024)
        val values = digests.map {
            require(it is String && Regex("^[a-f0-9]{64}$").matches(it))
            it
        }
        require(values.distinct().size == values.size)
        return values
    }

    fun preferenceKey(digest: String): String = "task_call_points_notice_$digest"
}
