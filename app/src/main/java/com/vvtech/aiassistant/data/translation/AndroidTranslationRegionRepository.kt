package com.vvtech.aiassistant.data.translation

import android.content.Context
import android.location.Geocoder
import com.vvtech.aiassistant.domain.translation.TranslationCoordinates
import com.vvtech.aiassistant.domain.translation.TranslationCountryCodeResolver
import com.vvtech.aiassistant.domain.translation.TranslationLocationSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.domain.translation.TranslationRegionStore
import com.vvtech.aiassistant.domain.translation.TrustedTranslationRegion
import com.vvtech.aiassistant.location.FusedLocationProvider
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal fun createAndroidTranslationRegionRepository(
    context: Context
): TranslationRegionRepository {
    val appContext = context.applicationContext
    return DefaultTranslationRegionRepository(
        locationSource = AndroidTranslationLocationSource(appContext),
        countryResolver = AndroidTranslationCountryCodeResolver(appContext),
        store = SharedPreferencesTranslationRegionStore(appContext)
    )
}

private class AndroidTranslationLocationSource(
    context: Context
) : TranslationLocationSource {
    private val provider = FusedLocationProvider(context.applicationContext)

    override suspend fun currentCoordinates(): TranslationCoordinates? {
        val result = provider.locateOnce()
        val payload = result.userContext
        if (!result.success || payload?.lat == null || payload.lng == null) return null
        return TranslationCoordinates(payload.lat, payload.lng)
    }
}

private class AndroidTranslationCountryCodeResolver(
    context: Context
) : TranslationCountryCodeResolver {
    private val appContext = context.applicationContext

    override suspend fun countryIso(coordinates: TranslationCoordinates): String? {
        return withContext(Dispatchers.IO) {
            runCatching {
                @Suppress("DEPRECATION")
                Geocoder(appContext, Locale.CHINA)
                    .getFromLocation(coordinates.latitude, coordinates.longitude, 1)
                    ?.firstOrNull()
                    ?.countryCode
            }.getOrNull()
        }
    }
}

private class SharedPreferencesTranslationRegionStore(
    context: Context
) : TranslationRegionStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        PreferencesName,
        Context.MODE_PRIVATE
    )

    override fun load(): TrustedTranslationRegion? {
        val iso = preferences.getString(CountryIsoKey, null)?.trim().orEmpty()
        val sampledAtMs = preferences.getLong(SampledAtMsKey, 0L)
        return if (iso.isBlank() || sampledAtMs <= 0L) {
            null
        } else {
            TrustedTranslationRegion(iso, sampledAtMs)
        }
    }

    override fun save(region: TrustedTranslationRegion) {
        preferences.edit()
            .putString(CountryIsoKey, region.countryIso)
            .putLong(SampledAtMsKey, region.sampledAtMs)
            .apply()
    }

    private companion object {
        const val PreferencesName = "translation_region_state"
        const val CountryIsoKey = "trusted_country_iso"
        const val SampledAtMsKey = "trusted_country_sampled_at_ms"
    }
}
