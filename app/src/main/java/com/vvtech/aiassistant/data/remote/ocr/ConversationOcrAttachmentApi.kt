package com.vvtech.aiassistant.data.remote.ocr

import com.vvtech.aiassistant.model.ApiResponse
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Streaming

interface ConversationOcrAttachmentApi {
    @Multipart
    @POST("api/agent/conversations/{sessionId}/ocr-images")
    suspend fun commit(
        @Path("sessionId") sessionId: String,
        @Part image: MultipartBody.Part,
        @Part("metadata") metadata: RequestBody,
    ): ApiResponse<ConversationOcrCommitResponseDto>

    @Streaming
    @GET("api/agent/conversations/{sessionId}/attachments/{attachmentId}/content")
    suspend fun content(
        @Path("sessionId") sessionId: String,
        @Path("attachmentId") attachmentId: String,
    ): Response<ResponseBody>
}

data class ConversationOcrFieldDto(
    val label: String,
    val value: String,
)

data class ConversationOcrCommitMetadataDto(
    val attachmentId: String,
    val commandId: String,
    val idempotencyKey: String,
    val traceId: String,
    val anchorStepCount: Int,
    val createdOrdinal: Long,
    val initialOpening: String?,
    val rawSegments: List<String>,
    val rawText: String,
)

data class ConversationOcrCommitResponseDto(
    val attachmentId: String,
    val sessionId: String,
    val contentPath: String,
    val contentType: String,
    val fileSize: Long,
    val anchorStepCount: Int,
    val createdOrdinal: Long,
    val fields: List<ConversationOcrFieldDto>,
    val segments: List<String>,
    val fullText: String,
    val eventId: String,
    val sequence: Long,
    val committedAt: String,
)
