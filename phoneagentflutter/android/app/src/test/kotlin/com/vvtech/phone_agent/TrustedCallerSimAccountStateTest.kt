package com.vvtech.phone_agent
import org.junit.Assert.*
import org.junit.Test

class TrustedCallerSimAccountStateTest {
    private val owner = TrustedCallerAccountOwner("synthetic", "13800000000", 1, "test")
    private fun surface(value: TrustedCallerAccountOwner = owner) = TrustedCallerSurface(
        "a".repeat(32), value.accountId, value.phone, value.loginEpoch, value.environment)
    @Test fun logoutDetachAndReplacementLeaveSdkNumbersUntouched() {
        val sdk = mutableMapOf(0 to "13900000000", 1 to "13700000000")
        val state = TrustedCallerSimAccountState { slot, number -> sdk[slot] = number }
        val c = state.attachConsumer()
        state.updateAccount(owner, c)
        state.synchronize(surface(), c, listOf(TrustedCallerSimWrite(0, owner.phone, true)))
        assertEquals(owner.phone, sdk[0])
        state.updateAccount(null, c)
        state.detachConsumer(c)
        state.attachConsumer()
        assertEquals(owner.phone, sdk[0])
        assertEquals("13700000000", sdk[1])
    }
    @Test fun newAccountOverwritesOnlyPlannedSlotsAndNoSimDoesNotClear() {
        val sdk = mutableMapOf(0 to "13900000000", 1 to "13700000000")
        val state = TrustedCallerSimAccountState { slot, number -> sdk[slot] = number }
        val c = state.attachConsumer()
        state.updateAccount(owner, c)
        assertTrue(state.synchronize(surface(), c, emptyList()))
        assertEquals("13900000000", sdk[0])
        assertTrue(state.synchronize(surface(), c, listOf(TrustedCallerSimWrite(1, owner.phone, true))))
        assertEquals("13900000000", sdk[0])
        assertEquals(owner.phone, sdk[1])
    }
    @Test fun staleChannelCannotWriteCurrentSdkButDoesNotClearExistingValues() {
        var writes = 0
        val state = TrustedCallerSimAccountState { _, _ -> writes++ }
        val old = state.attachConsumer()
        state.updateAccount(owner, old)
        val current = state.attachConsumer()
        state.updateAccount(owner, current)
        state.detachConsumer(old)
        assertFalse(state.synchronize(surface(), old, listOf(TrustedCallerSimWrite(0, owner.phone, true))))
        assertTrue(state.synchronize(surface(), current, listOf(TrustedCallerSimWrite(0, owner.phone, true))))
        assertEquals(1, writes)
    }
}
