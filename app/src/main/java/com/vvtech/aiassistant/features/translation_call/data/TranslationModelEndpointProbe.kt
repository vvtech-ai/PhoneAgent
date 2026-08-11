package com.vvtech.aiassistant.features.translation_call.data

import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.callengine.AssistantCallEngineConfiguration
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.domain.translation.TranslationRealtimeProvider
import com.vvtech.aiassistant.domain.translation.TranslationServiceRegion
import com.vvtech.aiassistant.features.translation_call.model.TranslationServiceEndpointResolver
import com.vvtech.aiassistant.logging.AppFileLogger
import java.net.HttpURLConnection
import java.net.URL

internal fun interface TranslationModelNetworkProbe {
    fun probe(
        provider: TranslationRealtimeProvider,
        serviceRegion: TranslationServiceRegion
    ): TranslationEnvironmentComponent
}

internal class TranslationModelEndpointProbe : TranslationModelNetworkProbe {
    private val backendResolver = TranslationServiceEndpointResolver(
        defaultBaseUrl = BuildConfig.TRANSLATION_WEBRTC_DEFAULT_URL,
        unitedStatesBaseUrl = BuildConfig.TRANSLATION_WEBRTC_US_URL,
        japanBaseUrl = BuildConfig.TRANSLATION_WEBRTC_JP_URL
    )

    override fun probe(
        provider: TranslationRealtimeProvider,
        serviceRegion: TranslationServiceRegion
    ): TranslationEnvironmentComponent {
        val endpoint = endpoint(provider, serviceRegion)
        if (endpoint.isBlank()) return unavailable(provider, serviceRegion, "MISSING_ENDPOINT")
        val startedAtNs = System.nanoTime()
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(endpoint.toHttpUrl()).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = TimeoutMs
            connection.readTimeout = TimeoutMs
            connection.setRequestProperty("Accept", "*/*")
            connection.setRequestProperty("Cache-Control", "no-cache")
            connection.setRequestProperty("Connection", "close")
            connection.setRequestProperty("Range", "bytes=0-0")
            val statusCode = connection.responseCode
            val latencyMs = elapsedMs(startedAtNs)
            if (statusCode in 100..499) {
                AppFileLogger.i(
                    LogTag,
                    "provider=$provider serviceRegion=$serviceRegion status=AVAILABLE " +
                        "latencyMs=$latencyMs httpStatus=$statusCode"
                )
                TranslationEnvironmentComponent(
                    state = TranslationEnvironmentState.Available,
                    latencyMs = latencyMs,
                    detail = "HTTP_$statusCode"
                )
            } else {
                unavailable(provider, serviceRegion, "HTTP_$statusCode", latencyMs)
            }
        } catch (error: Exception) {
            unavailable(
                provider,
                serviceRegion,
                error.javaClass.simpleName.ifBlank { "PROBE_FAILED" },
                elapsedMs(startedAtNs)
            )
        } finally {
            connection?.disconnect()
        }
    }

    private fun endpoint(
        provider: TranslationRealtimeProvider,
        serviceRegion: TranslationServiceRegion
    ): String = when (provider) {
        TranslationRealtimeProvider.Qwen ->
            AssistantCallEngineConfiguration.backendWebSocketUrl("qwen")
        TranslationRealtimeProvider.Doubao ->
            AssistantCallEngineConfiguration.backendWebSocketUrl("doubao")
        TranslationRealtimeProvider.OpenAi,
        TranslationRealtimeProvider.Gemini ->
            "${backendResolver.resolve(serviceRegion).baseUrl}/api/app-translation-calls/languages"
    }

    private fun unavailable(
        provider: TranslationRealtimeProvider,
        serviceRegion: TranslationServiceRegion,
        detail: String,
        latencyMs: Long? = null
    ): TranslationEnvironmentComponent {
        AppFileLogger.w(
            LogTag,
            "provider=$provider serviceRegion=$serviceRegion status=UNAVAILABLE " +
                "latencyMs=${latencyMs ?: -1} detail=$detail"
        )
        return TranslationEnvironmentComponent(
            state = TranslationEnvironmentState.Unavailable,
            latencyMs = latencyMs,
            detail = detail
        )
    }

    private fun String.toHttpUrl(): String = when {
        startsWith("wss://", ignoreCase = true) -> "https://${substring(6)}"
        startsWith("ws://", ignoreCase = true) -> "http://${substring(5)}"
        else -> this
    }

    private fun elapsedMs(startedAtNs: Long): Long =
        ((System.nanoTime() - startedAtNs) / 1_000_000L).coerceAtLeast(0L)

    private companion object {
        const val TimeoutMs = 2_500
        const val LogTag = "TranslationModelQuality"
    }
}
