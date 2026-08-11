package com.vvtech.aiassistant.callengine

internal object AssistantOriginalAudioGainCurve {
    fun gain(percent: Int): Float {
        return percent.coerceIn(0, 100) / 100f
    }
}
