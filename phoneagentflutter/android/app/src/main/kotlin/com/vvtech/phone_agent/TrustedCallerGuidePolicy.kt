package com.vvtech.phone_agent

/** Reference-global display fact; never a certificate authorization query. */
internal object TrustedCallerGuidePolicy {
    const val KEY = "trusted_callee_sdk_guide_seen"
    const val HOME_SEEN = "trusted_callee_guide_seen"
    const val HOME_DISABLED = "trusted_callee_guide_disabled"
    fun homeEligible(flags: Map<String, *>): Boolean =
        flags[HOME_SEEN] != true && flags[HOME_DISABLED] != true && !seen(flags)
    fun seen(flags: Map<String, *>): Boolean = flags[KEY] == true ||
        flags["trusted_callee_authorized"] == true ||
        // Previous Flutter versions used environment/account hashes in this same private file.
        flags.any { (key, value) -> key.matches(Regex("[0-9a-f]{64}")) && value == true }
}
