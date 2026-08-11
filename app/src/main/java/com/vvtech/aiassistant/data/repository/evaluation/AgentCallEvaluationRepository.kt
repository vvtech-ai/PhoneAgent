package com.vvtech.aiassistant.data.repository.evaluation

import com.vvtech.aiassistant.data.remote.evaluation.AgentCallEvaluationApi
import com.vvtech.aiassistant.data.remote.evaluation.AgentCallEvaluationDto
import com.vvtech.aiassistant.data.remote.evaluation.AgentBatchCallEvaluationDto
import com.vvtech.aiassistant.data.remote.evaluation.AgentCallRatingRequestDto
import com.vvtech.aiassistant.network.NetworkModule

internal data class AgentCallEvaluation(
    val callId: String,
    val modelName: String,
    val minimumLatencyMs: Long?,
    val maximumLatencyMs: Long?,
    val rating: String?,
)

internal interface AgentCallEvaluationRepository {
    suspend fun get(callId: String): AgentCallEvaluation
    suspend fun rate(callId: String, rating: String): AgentCallEvaluation
    suspend fun getBatch(batchId: String): AgentCallEvaluation
    suspend fun rateBatch(batchId: String, rating: String): AgentCallEvaluation
}

internal class DefaultAgentCallEvaluationRepository(
    private val api: AgentCallEvaluationApi,
) : AgentCallEvaluationRepository {
    override suspend fun get(callId: String): AgentCallEvaluation =
        api.getEvaluation(callId).requireData().toDomain()

    override suspend fun rate(callId: String, rating: String): AgentCallEvaluation =
        api.updateEvaluation(callId, AgentCallRatingRequestDto(rating)).requireData().toDomain()

    override suspend fun getBatch(batchId: String): AgentCallEvaluation =
        api.getBatchEvaluation(batchId).requireBatchData().toDomain()

    override suspend fun rateBatch(batchId: String, rating: String): AgentCallEvaluation =
        api.updateBatchEvaluation(batchId, AgentCallRatingRequestDto(rating)).requireBatchData().toDomain()

    private fun com.vvtech.aiassistant.model.ApiResponse<AgentCallEvaluationDto>.requireData() =
        data.takeIf { code == 0 } ?: error("Call evaluation is unavailable")

    private fun AgentCallEvaluationDto.toDomain() = AgentCallEvaluation(
        callId = callId,
        modelName = modelName.orEmpty().trim(),
        minimumLatencyMs = averageLatencyMs,
        maximumLatencyMs = averageLatencyMs,
        rating = rating?.trim()?.uppercase(),
    )

    private fun com.vvtech.aiassistant.model.ApiResponse<AgentBatchCallEvaluationDto>.requireBatchData() =
        data.takeIf { code == 0 } ?: error("Batch call evaluation is unavailable")

    private fun AgentBatchCallEvaluationDto.toDomain() = AgentCallEvaluation(
        callId = batchId,
        modelName = modelName.orEmpty().trim(),
        minimumLatencyMs = minimumLatencyMs,
        maximumLatencyMs = maximumLatencyMs,
        rating = rating?.trim()?.uppercase(),
    )
}

internal object AgentCallEvaluationRepositoryProvider {
    val repository: AgentCallEvaluationRepository by lazy {
        DefaultAgentCallEvaluationRepository(NetworkModule.agentCallEvaluationApi)
    }
}
