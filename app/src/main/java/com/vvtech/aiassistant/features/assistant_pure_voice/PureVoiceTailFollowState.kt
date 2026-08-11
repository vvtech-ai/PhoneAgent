package com.vvtech.aiassistant.features.assistant_pure_voice

internal data class PureVoiceTailFollowState(
    val followingTail: Boolean = true,
) {
    fun onListSnapshot(
        isScrollInProgress: Boolean,
        canScrollForward: Boolean,
    ): PureVoiceTailFollowState = when {
        isScrollInProgress -> copy(followingTail = !canScrollForward)
        !canScrollForward -> copy(followingTail = true)
        else -> this
    }
}
