package com.vvtech.aiassistant.callengine

internal object AssistantSipInviteRetryPolicy {
    private const val MaxRetries = 1
    private const val MaxRetryElapsedMillis = 5_000L
    private val RetryableSipMethods = setOf("REGISTER", "INVITE")

    fun shouldRetry(
        failure: AssistantCallEngineEvent.Failure,
        retriesUsed: Int,
        connected: Boolean,
        ringing: Boolean,
        elapsedSinceAttemptStartMillis: Long
    ): Boolean {
        return !connected &&
            !ringing &&
            retriesUsed < MaxRetries &&
            elapsedSinceAttemptStartMillis in 0..MaxRetryElapsedMillis &&
            failure.sipMethod in RetryableSipMethods
    }
}
