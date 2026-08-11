package com.vvtech.aiassistant.data.homeconfig

import android.content.Context
import com.google.gson.Gson

internal class HomeConfigLocalDataSource(
    context: Context,
    private val gson: Gson = Gson()
) {
    private val prefs = context.applicationContext.getSharedPreferences(PrefsName, Context.MODE_PRIVATE)

    fun read(): CachedHomeConfig? {
        val json = prefs.getString(KeyJson, null) ?: return null
        return runCatching {
            CachedHomeConfig(gson.fromJson(json, HomeConfigDto::class.java), prefs.getString(KeyEtag, null))
        }.getOrNull()
    }

    fun write(dto: HomeConfigDto, etag: String?) {
        prefs.edit().putString(KeyJson, gson.toJson(dto)).putString(KeyEtag, etag).apply()
    }

    data class CachedHomeConfig(val dto: HomeConfigDto, val etag: String?)

    private companion object {
        const val PrefsName = "assistant_home_config_cache"
        const val KeyJson = "last_known_good_json"
        const val KeyEtag = "last_known_good_etag"
    }
}
