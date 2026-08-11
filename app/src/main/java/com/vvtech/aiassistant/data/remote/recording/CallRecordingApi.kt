package com.vvtech.aiassistant.data.remote.recording

import com.vvtech.aiassistant.model.ApiResponse
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

internal interface CallRecordingApi {
    @GET("api/agent-calls/{callId}/recording")
    suspend fun getRecording(
        @Path("callId") callId: String,
    ): ApiResponse<CallRecordingDto>

    @POST("api/agent-calls/{callId}/recording/play-token")
    suspend fun createPlayToken(
        @Path("callId") callId: String,
    ): ApiResponse<CallRecordingPlayTokenDto>
}

internal data class CallRecordingDto(
    val callId: String,
    val status: String,
    val durationMillis: Long? = null,
    val contentType: String? = null,
)

internal data class CallRecordingPlayTokenDto(
    val url: String,
    val contentType: String,
)
