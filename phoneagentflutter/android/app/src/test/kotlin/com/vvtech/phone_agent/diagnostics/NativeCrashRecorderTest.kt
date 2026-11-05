package com.vvtech.phone_agent.diagnostics

import org.junit.Assert.*
import org.junit.Test

class NativeCrashRecorderTest {
    @Test fun recordsBeforeForwardingOriginalThreadAndError() {
        val thread = Thread.currentThread()
        val error = IllegalStateException("private token")
        val order = mutableListOf<String>()
        val recorder = NativeCrashRecorder({ scope, value ->
            order.add("save")
            assertEquals("a".repeat(64), scope)
            assertEquals("state", value.kind)
            assertTrue(value.mainThread)
            assertFalse(value.payload(scope!!).toString().contains("private"))
        }, Thread.UncaughtExceptionHandler { actualThread, actualError ->
            order.add("forward")
            assertSame(thread, actualThread)
            assertSame(error, actualError)
        }, { it === thread })
        recorder.bind("a".repeat(64))
        recorder.uncaughtException(thread, error)
        assertEquals(listOf("save", "forward"), order)
    }

    @Test fun recorderFailureStillForwardsAndNoPredecessorRethrowsOriginal() {
        val error = IllegalArgumentException("private")
        var forwarded = 0
        val recorder = NativeCrashRecorder({ _, _ -> throw OutOfMemoryError() },
            Thread.UncaughtExceptionHandler { _, actual -> assertSame(error, actual); forwarded++ }, { false })
        recorder.uncaughtException(Thread.currentThread(), error)
        assertEquals(1, forwarded)
        val noPrevious = NativeCrashRecorder({ _, _ -> throw AssertionError() }, null, { false })
        val thrown = assertThrows(IllegalArgumentException::class.java) {
            noPrevious.uncaughtException(Thread.currentThread(), error)
        }
        assertSame(error, thrown)
    }

    @Test fun unboundAndClearedScopeNeverReuseAccountAndNoMessageAccess() {
        val scopes = mutableListOf<String?>()
        val kinds = mutableListOf<String>()
        val recorder = NativeCrashRecorder({ scope, value -> scopes.add(scope); kinds.add(value.kind) },
            Thread.UncaughtExceptionHandler { _, _ -> }, { false })
        val poison = object : RuntimeException() {
            override val message: String get() = throw AssertionError("must not read")
            override fun toString(): String = throw AssertionError("must not stringify")
        }
        recorder.uncaughtException(Thread.currentThread(), poison)
        recorder.bind("b".repeat(64))
        recorder.uncaughtException(Thread.currentThread(), AssertionError("secret"))
        recorder.bind(null)
        recorder.uncaughtException(Thread.currentThread(), poison)
        assertEquals(listOf(null, "b".repeat(64), null), scopes)
        assertEquals(listOf("other", "assertion", "other"), kinds)
    }

    @Test fun previousHandlerFailureIsNotReplaced() {
        val sentinel = AssertionError("previous handler")
        val recorder = NativeCrashRecorder({ _, _ -> },
            Thread.UncaughtExceptionHandler { _, _ -> throw sentinel }, { false })
        assertSame(sentinel, assertThrows(AssertionError::class.java) {
            recorder.uncaughtException(Thread.currentThread(), IllegalStateException())
        })
    }
}
