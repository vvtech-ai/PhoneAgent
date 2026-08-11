package com.vvtech.aiassistant.data.translation

import com.vvtech.aiassistant.domain.translation.TranslationCoordinates
import com.vvtech.aiassistant.domain.translation.TranslationCountryCodeResolver
import com.vvtech.aiassistant.domain.translation.TranslationLocationSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import com.vvtech.aiassistant.domain.translation.TranslationRegionStore
import com.vvtech.aiassistant.domain.translation.TrustedTranslationRegion
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DefaultTranslationRegionRepositoryTest {
    @Test
    fun `cached region is exposed before refresh`() {
        val store = MemoryStore(TrustedTranslationRegion("cn", 10L))
        val repository = repository(store = store)

        val state = repository.state.value as TranslationRegionState.Resolved

        assertEquals("CN", state.countryIso)
        assertEquals(TranslationRegionSource.TrustedCache, state.source)
    }

    @Test
    fun `successful refresh persists live country`() = runBlocking {
        val store = MemoryStore()
        val repository = repository(store = store, resolvedIso = "jp")

        val state = repository.refresh() as TranslationRegionState.Resolved

        assertEquals("JP", state.countryIso)
        assertEquals(TranslationRegionSource.LiveLocation, state.source)
        assertEquals(100L, state.sampledAtMs)
        assertEquals(TrustedTranslationRegion("JP", 100L), store.saved)
    }

    @Test
    fun `failed refresh retains trusted cache`() = runBlocking {
        val store = MemoryStore(TrustedTranslationRegion("US", 20L))
        val repository = repository(store = store, coordinates = null)

        val state = repository.refresh() as TranslationRegionState.Resolved

        assertEquals("US", state.countryIso)
        assertEquals(TranslationRegionSource.TrustedCache, state.source)
        assertEquals(20L, state.sampledAtMs)
    }

    @Test
    fun `failed refresh without cache becomes unavailable`() = runBlocking {
        val repository = repository(store = MemoryStore(), coordinates = null)

        val state = repository.refresh()

        assertTrue(state is TranslationRegionState.Unavailable)
    }

    @Test
    fun `invalid coordinates never reach country resolver`() = runBlocking {
        var resolverCalled = false
        val repository = DefaultTranslationRegionRepository(
            locationSource = object : TranslationLocationSource {
                override suspend fun currentCoordinates() = TranslationCoordinates(0.0, 0.0)
            },
            countryResolver = object : TranslationCountryCodeResolver {
                override suspend fun countryIso(coordinates: TranslationCoordinates): String? {
                    resolverCalled = true
                    return "CN"
                }
            },
            store = MemoryStore()
        )

        assertTrue(repository.refresh() is TranslationRegionState.Unavailable)
        assertEquals(false, resolverCalled)
    }

    private fun repository(
        store: MemoryStore,
        coordinates: TranslationCoordinates? = TranslationCoordinates(31.2, 121.5),
        resolvedIso: String? = "CN"
    ) = DefaultTranslationRegionRepository(
        locationSource = object : TranslationLocationSource {
            override suspend fun currentCoordinates() = coordinates
        },
        countryResolver = object : TranslationCountryCodeResolver {
            override suspend fun countryIso(coordinates: TranslationCoordinates) = resolvedIso
        },
        store = store,
        nowMs = { 100L }
    )

    private class MemoryStore(
        private var initial: TrustedTranslationRegion? = null
    ) : TranslationRegionStore {
        var saved: TrustedTranslationRegion? = null

        override fun load() = saved ?: initial

        override fun save(region: TrustedTranslationRegion) {
            saved = region
            initial = region
        }
    }
}
