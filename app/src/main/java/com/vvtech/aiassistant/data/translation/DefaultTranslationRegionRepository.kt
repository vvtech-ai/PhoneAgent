package com.vvtech.aiassistant.data.translation

import com.vvtech.aiassistant.domain.translation.TranslationCountryCodeResolver
import com.vvtech.aiassistant.domain.translation.TranslationLocationSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationRegionStore
import com.vvtech.aiassistant.domain.translation.TrustedTranslationRegion
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class DefaultTranslationRegionRepository(
    private val locationSource: TranslationLocationSource,
    private val countryResolver: TranslationCountryCodeResolver,
    private val store: TranslationRegionStore,
    private val nowMs: () -> Long = System::currentTimeMillis
) : TranslationRegionRepository {
    private val refreshMutex = Mutex()
    private val mutableState = MutableStateFlow(initialState())

    override val state: StateFlow<TranslationRegionState> = mutableState.asStateFlow()

    override suspend fun refresh(): TranslationRegionState = refreshMutex.withLock {
        val previous = mutableState.value as? TranslationRegionState.Resolved
        if (previous == null) mutableState.value = TranslationRegionState.Resolving

        val countryIso = runCatching {
            locationSource.currentCoordinates()
                ?.takeIf(::validCoordinates)
                ?.let { countryResolver.countryIso(it) }
                ?.normalizeCountryIso()
        }.getOrNull()

        val next = if (countryIso != null) {
            val trusted = TrustedTranslationRegion(countryIso, nowMs())
            store.save(trusted)
            TranslationRegionState.Resolved(
                countryIso = trusted.countryIso,
                source = TranslationRegionSource.LiveLocation,
                sampledAtMs = trusted.sampledAtMs
            )
        } else {
            previous?.copy(source = TranslationRegionSource.TrustedCache)
                ?: cachedState()
                ?: TranslationRegionState.Unavailable("无法确定当前位置，请授权定位后重试")
        }
        mutableState.value = next
        next
    }

    private fun initialState(): TranslationRegionState {
        return cachedState()
            ?: TranslationRegionState.Unavailable("尚未获取可信位置")
    }

    private fun cachedState(): TranslationRegionState.Resolved? {
        val trusted = store.load() ?: return null
        val countryIso = trusted.countryIso.normalizeCountryIso() ?: return null
        return TranslationRegionState.Resolved(
            countryIso = countryIso,
            source = TranslationRegionSource.TrustedCache,
            sampledAtMs = trusted.sampledAtMs
        )
    }

    private fun validCoordinates(value: com.vvtech.aiassistant.domain.translation.TranslationCoordinates) =
        value.latitude.isFinite() &&
            value.longitude.isFinite() &&
            value.latitude in -90.0..90.0 &&
            value.longitude in -180.0..180.0 &&
            !(value.latitude == 0.0 && value.longitude == 0.0)

    private fun String.normalizeCountryIso(): String? {
        val normalized = trim().uppercase(Locale.ROOT)
        return normalized.takeIf { it.matches(Regex("[A-Z]{2}")) }
    }
}
