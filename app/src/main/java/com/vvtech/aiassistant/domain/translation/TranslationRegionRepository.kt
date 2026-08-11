package com.vvtech.aiassistant.domain.translation

import kotlinx.coroutines.flow.StateFlow

data class TranslationCoordinates(
    val latitude: Double,
    val longitude: Double
)

data class TrustedTranslationRegion(
    val countryIso: String,
    val sampledAtMs: Long
)

interface TranslationLocationSource {
    suspend fun currentCoordinates(): TranslationCoordinates?
}

interface TranslationCountryCodeResolver {
    suspend fun countryIso(coordinates: TranslationCoordinates): String?
}

interface TranslationRegionStore {
    fun load(): TrustedTranslationRegion?
    fun save(region: TrustedTranslationRegion)
}

interface TranslationRegionRepository {
    val state: StateFlow<TranslationRegionState>
    suspend fun refresh(): TranslationRegionState
}
