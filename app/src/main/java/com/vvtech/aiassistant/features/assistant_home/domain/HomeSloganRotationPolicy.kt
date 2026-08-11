package com.vvtech.aiassistant.features.assistant_home.domain

internal object HomeSloganRotationPolicy {
    data class Result(val selectedIndex: Int, val nextIndex: Int)

    fun next(
        savedVersion: String?,
        configVersion: String,
        savedIndex: Int,
        sloganCount: Int
    ): Result {
        require(sloganCount > 0)
        val selected = if (savedVersion == configVersion) savedIndex.mod(sloganCount) else 0
        return Result(selected, (selected + 1).mod(sloganCount))
    }
}
