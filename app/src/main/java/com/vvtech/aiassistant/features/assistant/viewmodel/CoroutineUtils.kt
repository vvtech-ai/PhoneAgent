package com.vvtech.aiassistant.features.assistant.viewmodel

import kotlinx.coroutines.CancellationException

/**
 * Coroutine-safe alternative to [runCatching].
 *
 * Standard [runCatching] catches [CancellationException], which breaks structured concurrency:
 * the coroutine's cooperative cancellation signal is swallowed, and the `.onFailure` block then
 * surfaces the raw exception message (e.g. "StandaloneCoroutine was cancelled") as a UI error.
 *
 * This helper re-throws [CancellationException] so the coroutine framework can propagate it
 * correctly, while still wrapping every other [Throwable] in a [Result.failure].
 */
internal inline fun <R> runCatchingNonCancellation(block: () -> R): Result<R> {
    return try {
        Result.success(block())
    } catch (e: CancellationException) {
        throw e   // Must re-throw — this is the cooperative cancellation signal
    } catch (e: Throwable) {
        Result.failure(e)
    }
}
