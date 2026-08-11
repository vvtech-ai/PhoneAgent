package com.vvtech.aiassistant.callengine

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

internal class AssistantTranslationIntroGate(
    private val nanoTime: () -> Long = System::nanoTime
) {
    private val liveInputSuppressed = AtomicBoolean(false)
    private val triggerResponseBoundaryExpected = AtomicBoolean(false)
    private val triggerResponsePending = AtomicBoolean(false)
    private val modelOutputSuppressedUntil = AtomicLong(0L)

    fun enter(expectTriggerResponseBoundary: Boolean = false): Boolean {
        if (!liveInputSuppressed.compareAndSet(false, true)) return false
        triggerResponseBoundaryExpected.set(expectTriggerResponseBoundary)
        triggerResponsePending.set(expectTriggerResponseBoundary)
        modelOutputSuppressedUntil.set(0L)
        return true
    }

    fun shouldSuppressLiveInput(): Boolean = liveInputSuppressed.get()

    fun shouldSuppressModelOutput(): Boolean =
        liveInputSuppressed.get() ||
            triggerResponsePending.get() ||
            nanoTime() < modelOutputSuppressedUntil.get()

    fun finishIntroPlayback() {
        liveInputSuppressed.set(false)
        if (!triggerResponseBoundaryExpected.get()) {
            modelOutputSuppressedUntil.set(nanoTime() + ModelOutputGraceNanos)
        }
    }

    fun release() = finishIntroPlayback()

    fun completeTriggerResponse(): Boolean {
        if (!triggerResponseBoundaryExpected.get()) return false
        val completed = triggerResponsePending.compareAndSet(true, false)
        if (completed) modelOutputSuppressedUntil.set(0L)
        return completed
    }

    fun failClosed() {
        liveInputSuppressed.set(true)
        triggerResponseBoundaryExpected.set(true)
        triggerResponsePending.set(true)
        modelOutputSuppressedUntil.set(Long.MAX_VALUE)
    }

    fun cancel() {
        liveInputSuppressed.set(false)
        triggerResponseBoundaryExpected.set(false)
        triggerResponsePending.set(false)
        modelOutputSuppressedUntil.set(0L)
    }

    private companion object {
        const val ModelOutputGraceNanos = 800_000_000L
    }
}
