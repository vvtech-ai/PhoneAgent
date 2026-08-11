package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch

internal class BackendMerchantCallStarter(
    private val client: BackendTranslationClient,
    private val clockMs: () -> Long = System::currentTimeMillis,
    private val sleepMs: (Long) -> Unit = Thread::sleep
) {
    fun start(
        request: BackendStartMerchantCallRequest,
        onEnvironment: (TranslationCallEnvironmentPatch) -> Unit
    ): BackendStartMerchantCallResult {
        val deadline = clockMs() + RetryWindowMs
        while (true) {
            try {
                return client.startMerchantCall(request).also {
                    it.environment?.let(onEnvironment)
                }
            } catch (error: BackendTranslationHttpException) {
                error.environment?.let(onEnvironment)
                if (
                    error.statusCode != 409 ||
                    !error.code.equals(MediaNotReadyCode, ignoreCase = true) ||
                    clockMs() >= deadline
                ) {
                    throw error
                }
                sleepMs(RetryIntervalMs)
            }
        }
    }

    private companion object {
        const val RetryIntervalMs = 500L
        const val RetryWindowMs = 10_000L
        const val MediaNotReadyCode = "MEDIA_CHANNEL_NOT_READY"
    }
}
