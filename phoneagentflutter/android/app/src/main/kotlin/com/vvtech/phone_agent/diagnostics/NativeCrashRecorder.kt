package com.vvtech.phone_agent.diagnostics

import java.util.concurrent.atomic.AtomicBoolean

class NativeCrashRecorder(
    private val save: (String?, CrashSummary) -> Unit,
    private val previous: Thread.UncaughtExceptionHandler?,
    private val isMainThread: (Thread) -> Boolean,
) : Thread.UncaughtExceptionHandler {
    @Volatile private var scope: String? = null
    private val recording = AtomicBoolean(false)

    fun bind(value: String?) {
        require(value == null || CrashSummary.SCOPE.matches(value))
        scope = value
    }

    override fun uncaughtException(thread: Thread, error: Throwable) {
        val capturedScope = scope
        try {
            if (recording.compareAndSet(false, true)) {
                try {
                    save(capturedScope, CrashSummary(
                        mainThread = isMainThread(thread), kind = CrashSummary.classify(error),
                    ))
                } finally {
                    recording.set(false)
                }
            }
        } catch (_: Throwable) {
            // Best effort, including memory pressure or keystore failure.
        } finally {
            if (previous != null) previous.uncaughtException(thread, error) else throw error
        }
    }
}
