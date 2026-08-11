package com.vvtech.aiassistant.domain.usecase

import com.vvtech.aiassistant.core.model.AssistantMessageRequest
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.RealtimeSessionResponse
import com.vvtech.aiassistant.core.model.StartRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.StopRealtimeSessionRequest
import com.vvtech.aiassistant.core.model.StopRealtimeSessionResponse
import com.vvtech.aiassistant.data.repository.AssistantRepository

class LoadAssistantSessionUseCase(
    private val repository: AssistantRepository
) {
    suspend operator fun invoke(userId: String): AssistantSessionResponse = repository.loadLatestSession(userId)
}

class SendAssistantTurnUseCase(
    private val repository: AssistantRepository
) {
    suspend operator fun invoke(request: AssistantMessageRequest): AssistantSessionResponse = repository.sendMessage(request)
}

class StartRealtimeSessionUseCase(
    private val repository: AssistantRepository
) {
    suspend operator fun invoke(request: StartRealtimeSessionRequest): RealtimeSessionResponse =
        repository.startRealtimeSession(request)
}

class StopRealtimeSessionUseCase(
    private val repository: AssistantRepository
) {
    suspend operator fun invoke(request: StopRealtimeSessionRequest): StopRealtimeSessionResponse =
        repository.stopRealtimeSession(request)
}
