package com.vvtech.phone_agent

/** Channel ownership only. Reference does not clear SDK numbers on logout/detach. */
internal class TrustedCallerSimAccountState(private val write: (Int, String) -> Unit) {
    private var consumer = 0L
    private var owner: TrustedCallerAccountOwner? = null
    fun attachConsumer(): Long { consumer++; owner = null; return consumer }
    fun updateAccount(next: TrustedCallerAccountOwner?, capturedConsumer: Long): Boolean {
        if (capturedConsumer != consumer) return false
        owner = next
        return true
    }
    fun current(surface: TrustedCallerSurface, capturedConsumer: Long): Boolean =
        capturedConsumer == consumer && owner?.matches(surface) == true
    fun synchronize(surface: TrustedCallerSurface, capturedConsumer: Long, plan: List<TrustedCallerSimWrite>): Boolean {
        if (!current(surface, capturedConsumer)) return false
        return try {
            for (item in plan) write(item.slot, item.number)
            true
        } catch (_: Exception) { false }
    }
    fun detachConsumer(capturedConsumer: Long) {
        if (capturedConsumer != consumer) return
        consumer++; owner = null
    }
}
