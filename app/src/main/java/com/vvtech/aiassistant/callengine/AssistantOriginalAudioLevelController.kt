package com.vvtech.aiassistant.callengine

import kotlin.math.pow
import kotlin.math.sqrt

internal data class AssistantOriginalAudioLevelDecision(
    val appliedGain: Float,
    val targetGain: Float,
    val balanced: Boolean,
    val gainLimited: Boolean
)

internal class AssistantOriginalAudioLevelController(
    targetOriginalRatio: Float,
    pureOriginalGain: Float = 1f,
    maxOriginalGain: Float = MaxOriginalGain
) {
    private val targetOriginalRatio = targetOriginalRatio.coerceIn(0f, 1f)
    private val pureOriginalGain = pureOriginalGain.coerceIn(0f, 1f)
    private val maxOriginalGain = maxOriginalGain.coerceIn(0f, MaxOriginalGain)
    private var translationWindowActive = false
    private var hasBalancedFrame = false
    private var currentGain = this.pureOriginalGain

    fun nextGain(
        original: ShortArray?,
        translated: ShortArray?,
        translationWindowActive: Boolean
    ): AssistantOriginalAudioLevelDecision {
        if (!translationWindowActive) {
            this.translationWindowActive = false
            hasBalancedFrame = false
            currentGain = pureOriginalGain
            return decision(
                appliedGain = currentGain,
                targetGain = currentGain,
                balanced = false,
                gainLimited = false
            )
        }
        if (!this.translationWindowActive) {
            this.translationWindowActive = true
            hasBalancedFrame = false
            currentGain = targetOriginalRatio
        }
        if (targetOriginalRatio == 0f) {
            currentGain = 0f
            return decision(
                appliedGain = currentGain,
                targetGain = currentGain,
                balanced = false,
                gainLimited = false
            )
        }

        val originalRms = rms(original)
        val translatedRms = rms(translated)
        val balanced =
            originalRms >= MinimumSpeechRms &&
                translatedRms >= MinimumSpeechRms
        if (!balanced) {
            return decision(
                appliedGain = currentGain,
                targetGain = currentGain,
                balanced = false,
                gainLimited = false
            )
        }

        val rawTargetGain = translatedRms * targetOriginalRatio / originalRms
        val targetGain = rawTargetGain.coerceIn(0.0, maxOriginalGain.toDouble()).toFloat()
        val gainLimited = rawTargetGain > maxOriginalGain
        currentGain = if (!hasBalancedFrame) {
            hasBalancedFrame = true
            targetGain
        } else {
            val smoothing = if (targetGain < currentGain) {
                AttenuationSmoothing
            } else {
                BoostSmoothing
            }
            currentGain + (targetGain - currentGain) * smoothing
        }
        return decision(
            appliedGain = currentGain,
            targetGain = targetGain,
            balanced = true,
            gainLimited = gainLimited
        )
    }

    private fun decision(
        appliedGain: Float,
        targetGain: Float,
        balanced: Boolean,
        gainLimited: Boolean
    ): AssistantOriginalAudioLevelDecision =
        AssistantOriginalAudioLevelDecision(
            appliedGain = appliedGain,
            targetGain = targetGain,
            balanced = balanced,
            gainLimited = gainLimited
        )

    private fun rms(samples: ShortArray?): Double {
        val pcm = samples?.takeIf { it.isNotEmpty() } ?: return 0.0
        return sqrt(pcm.sumOf { it.toDouble() * it.toDouble() } / pcm.size)
    }

    private companion object {
        const val MaxOriginalGain = 8f
        const val AttenuationSmoothing = 0.65f
        const val BoostSmoothing = 0.2f
        const val MinimumSpeechDbfs = -50.0
        val MinimumSpeechRms =
            Short.MAX_VALUE * 10.0.pow(MinimumSpeechDbfs / 20.0)
    }
}
