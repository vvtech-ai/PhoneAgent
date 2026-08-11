package com.vvtech.aiassistant.features.assistant_home.domain

internal interface HomeConfigRepository {
    suspend fun load(): HomeConfigLoadResult
}

internal class LoadHomeConfigUseCase(
    private val repository: HomeConfigRepository
) {
    suspend operator fun invoke(): HomeConfigLoadResult = repository.load()
}
