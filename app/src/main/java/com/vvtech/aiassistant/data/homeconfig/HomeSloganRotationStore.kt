package com.vvtech.aiassistant.data.homeconfig

import android.content.Context
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfig
import com.vvtech.aiassistant.features.assistant_home.domain.HomeSlogan
import com.vvtech.aiassistant.features.assistant_home.domain.HomeSloganRotationPolicy

internal class HomeSloganRotationStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PrefsName, Context.MODE_PRIVATE)

    fun next(config: HomeConfig): HomeSlogan {
        require(config.slogans.isNotEmpty())
        val savedVersion = prefs.getString(KeyVersion, null)
        val result = HomeSloganRotationPolicy.next(
            savedVersion = savedVersion,
            configVersion = config.configVersion,
            savedIndex = prefs.getInt(KeyIndex, 0),
            sloganCount = config.slogans.size
        )
        prefs.edit()
            .putString(KeyVersion, config.configVersion)
            .putInt(KeyIndex, result.nextIndex)
            .apply()
        return config.slogans[result.selectedIndex]
    }

    private companion object {
        const val PrefsName = "assistant_home_slogan_rotation"
        const val KeyVersion = "config_version"
        const val KeyIndex = "next_index"
    }
}
