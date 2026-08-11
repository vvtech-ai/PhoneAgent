package com.vvtech.aiassistant.data.remote.evaluation

import com.vvtech.aiassistant.model.ApiResponse
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PUT
import retrofit2.http.Path

internal interface AgentCallEvaluationApi {
    @GET("api/agent-calls/{callId}/evaluation")
    suspend fun getEvaluation(
        @Path("callId") callId: String,
    ): ApiResponse<AgentCallEvaluationDto>

    @PUT("api/agent-calls/{callId}/evaluation")
    suspend fun updateEvaluation(
        @Path("callId") callId: String,
        @Body request: AgentCallRatingRequestDto,
    ): ApiResponse<AgentCallEvaluationDto>

    @GET("api/agent-calls/batches/{batchId}/evaluation")
    suspend fun getBatchEvaluation(
        @Path("batchId") batchId: String,
    ): ApiResponse<AgentBatchCallEvaluationDto>

    @PUT("api/agent-calls/batches/{batchId}/evaluation")
    suspend fun updateBatchEvaluation(
        @Path("batchId") batchId: String,
        @Body request: AgentCallRatingRequestDto,
    ): ApiResponse<AgentBatchCallEvaluationDto>
}

internal data class AgentCallEvaluationDto(
    val callId: String,
    val modelProvider: String? = null,
    val modelName: String? = null,
    val averageLatencyMs: Long? = null,
    val validTurnCount: Int = 0,
    val skippedTurnCount: Int = 0,
    val rating: String? = null,
)

internal data class AgentBatchCallEvaluationDto(
    val batchId: String,
    val modelProvider: String? = null,
    val modelName: String? = null,
    val minimumLatencyMs: Long? = null,
    val maximumLatencyMs: Long? = null,
    val validTurnCount: Int = 0,
    val skippedTurnCount: Int = 0,
    val rating: String? = null,
)

internal data class AgentCallRatingRequestDto(val rating: String)
