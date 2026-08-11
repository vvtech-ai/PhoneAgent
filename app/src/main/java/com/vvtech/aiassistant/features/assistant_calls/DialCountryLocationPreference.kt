package com.vvtech.aiassistant.features.assistant_calls

import android.content.Context
import com.vvtech.aiassistant.features.assistant.FinalPrefsName

internal interface DialCountryLocationStore {
    fun readIso(): String?
    fun writeIso(iso: String)
}

internal class DialCountryLocationPreference(
    private val store: DialCountryLocationStore
) {
    fun load(): DialCountry? = resolveLocatedDialCountry(store.readIso())

    fun save(country: DialCountry) {
        if (resolveLocatedDialCountry(country.iso) != null) {
            store.writeIso(country.iso)
        }
    }
}

internal class SharedPreferencesDialCountryLocationStore(
    context: Context
) : DialCountryLocationStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        FinalPrefsName,
        Context.MODE_PRIVATE
    )

    override fun readIso(): String? = preferences.getString(LocatedCountryIsoKey, null)

    override fun writeIso(iso: String) {
        preferences.edit().putString(LocatedCountryIsoKey, iso).apply()
    }

    private companion object {
        const val LocatedCountryIsoKey = "dial_last_located_country_iso"
    }
}
