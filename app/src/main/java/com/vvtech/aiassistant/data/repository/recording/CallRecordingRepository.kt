package com.vvtech.aiassistant.data.repository.recording

import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.data.remote.recording.CallRecordingApi
import com.vvtech.aiassistant.network.NetworkModule

internal data class CallRecordingInfo(
    val callId: String,
    val status: String,
    val durationMillis: Long?,
    val contentType: String?,
)

internal data class CallRecordingPlaybackSource(
    val url: String,
    val contentType: String,
)

internal interface CallRecordingRepository {
    suspend fun getRecording(callId: String): CallRecordingInfo
    suspend fun createPlaybackSource(callId: String): CallRecordingPlaybackSource
}

internal class DefaultCallRecordingRepository(
    private val api: CallRecordingApi,
    private val baseUrl: String,
) : CallRecordingRepository {
    override suspend fun getRecording(callId: String): CallRecordingInfo {
        val response = api.getRecording(callId)
        val data = response.data.takeIf { response.code == 0 }
            ?: error("Call recording metadata is unavailable")
        return CallRecordingInfo(
            callId = data.callId,
            status = data.status,
            durationMillis = data.durationMillis,
            contentType = data.contentType,
        )
    }

    override suspend fun createPlaybackSource(callId: String): CallRecordingPlaybackSource {
        val response = api.createPlayToken(callId)
        val data = response.data.takeIf { response.code == 0 }
            ?: error("Call recording playback token is unavailable")
        return CallRecordingPlaybackSource(
            url = data.url.toAbsoluteUrl(baseUrl),
            contentType = data.contentType,
        )
    }
}

internal object CallRecordingRepositoryProvider {
    val repository: CallRecordingRepository by lazy {
        DefaultCallRecordingRepository(
            api = NetworkModule.callRecordingApi,
            baseUrl = BuildConfig.BASE_URL,
        )
    }
}

private fun String.toAbsoluteUrl(baseUrl: String): String {
    if (startsWith("http://") || startsWith("https://")) return this
    return "${baseUrl.trimEnd('/')}/${trimStart('/')}"
}
