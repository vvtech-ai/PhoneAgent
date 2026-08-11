package com.vvtech.aiassistant.data.homeconfig

import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigLoadResult
import com.vvtech.aiassistant.features.assistant_home.domain.HomeConfigSource

internal object HomeConfigFallbackPolicy {
    fun resolve(warning: String?): HomeConfigLoadResult =
        HomeConfigLoadResult(HomeConfigDefaults.create(), HomeConfigSource.Default, warning)
}
