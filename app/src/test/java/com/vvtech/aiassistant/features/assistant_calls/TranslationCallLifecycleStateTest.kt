package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallLifecycleStateTest {
    @Test
    fun sameAttemptCanFinalizeOnlyOnceAndKeepsDialerOrigin() {
        val state = TranslationCallLifecycleState()
        val attemptId = state.begin(TranslationCallOrigin.DIALER)

        val finalization = state.tryFinalize(attemptId, "call-1")

        assertTrue(attemptId.isNotBlank())
        assertEquals("call-1", finalization?.recordCallId)
        assertEquals(TranslationCallOrigin.DIALER, finalization?.origin)
        assertNull(state.tryFinalize(attemptId, "call-1"))
    }

    @Test
    fun failedStartWithoutRemoteCallIdGetsStableLocalIdentity() {
        val state = TranslationCallLifecycleState()
        val attemptId = state.begin(TranslationCallOrigin.DIALER)

        val finalization = state.tryFinalize(attemptId, "")

        assertNotNull(finalization)
        assertTrue(finalization!!.recordCallId.startsWith("local:"))
        assertNull(state.tryFinalize(attemptId, ""))
    }

    @Test
    fun separateAttemptsWithSameRemoteOutcomeRemainSeparate() {
        val state = TranslationCallLifecycleState()
        val firstAttempt = state.begin(TranslationCallOrigin.DIALER)
        val first = state.tryFinalize(firstAttempt, "call-1")
        state.clear()
        val secondAttempt = state.begin(TranslationCallOrigin.DIALER)
        val second = state.tryFinalize(secondAttempt, "call-2")

        assertEquals("call-1", first?.recordCallId)
        assertEquals("call-2", second?.recordCallId)
    }

    @Test
    fun staleAttemptCannotFinalizeANewerCall() {
        val state = TranslationCallLifecycleState()
        val firstAttempt = state.begin(TranslationCallOrigin.DIALER)
        val secondAttempt = state.begin(TranslationCallOrigin.DIALER)

        assertNull(state.tryFinalize(firstAttempt, "call-1"))
        assertNotNull(state.tryFinalize(secondAttempt, "call-2"))
    }

    @Test
    fun clearedAttemptCannotFinalizeAfterCancellation() {
        val state = TranslationCallLifecycleState()
        val cancelledAttempt = state.begin(TranslationCallOrigin.DIALER)

        state.clear()

        assertNull(state.tryFinalize(cancelledAttempt, "call-late"))
    }

    @Test
    fun restoredSnapshotKeepsDialerOrigin() {
        val restored = TranslationCallLifecycleState(
            initial = TranslationCallLifecycleSnapshot(
                activeAttemptId = "attempt-restored",
                origin = TranslationCallOrigin.DIALER
            )
        )

        val finalization = restored.tryFinalize("attempt-restored", "call-restored")

        assertEquals(TranslationCallOrigin.DIALER, finalization?.origin)
    }
}
