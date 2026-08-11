package com.vvtech.aiassistant.features.assistant_pure_voice

import com.vvtech.aiassistant.features.assistant.ClarificationStep

internal data class PureVoiceConversationProjection(
    val steps: List<ClarificationStep>,
    private val displayBoundaryBySourceBoundary: List<Int>,
) {
    fun displayBoundaryFor(sourceStepCount: Int): Int =
        displayBoundaryBySourceBoundary[
            sourceStepCount.coerceIn(0, displayBoundaryBySourceBoundary.lastIndex)
        ]
}
