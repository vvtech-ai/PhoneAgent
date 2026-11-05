package com.vvtech.phone_agent

internal object TrustedCallerSimReadPolicy {
    fun canReadSubscription(phoneState: Boolean, phoneNumbers: Boolean) = phoneState || phoneNumbers
    fun readNumber(local: () -> String?, sim: () -> String?, subscription: () -> String?): String {
        val sdk = TrustedCallerSimPlan.normalize(local() ?: sim())
        return sdk.ifBlank { TrustedCallerSimPlan.normalize(subscription()) }
    }
}
