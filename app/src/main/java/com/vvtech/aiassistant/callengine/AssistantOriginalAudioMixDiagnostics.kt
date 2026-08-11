package com.vvtech.aiassistant.callengine

import kotlin.math.roundToInt

internal class AssistantOriginalAudioMixDiagnostics {
    private var translatedFrames = 0
    private var originalHitFrames = 0
    private var originalSquareSum = 0.0
    private var originalSamples = 0
    private var translatedSquareSum = 0.0
    private var translatedSamples = 0
    private var outputSquareSum = 0.0
    private var outputSamples = 0
    private var originalContributionSquareSum = 0.0
    private var originalContributionSamples = 0
    private var appliedGainSum = 0.0
    private var minimumAppliedGain = Float.POSITIVE_INFINITY
    private var maximumAppliedGain = Float.NEGATIVE_INFINITY
    private var balancedFrames = 0
    private var gainLimitedFrames = 0
    private var originalPeak = 0
    private var translatedPeak = 0
    private var outputPeak = 0

    fun record(
        original: ShortArray?,
        translated: ShortArray?,
        output: ShortArray,
        level: AssistantOriginalAudioLevelDecision,
        targetOriginalRatio: Float
    ): String? {
        if (translated == null) return null
        translatedFrames++
        if (original != null && original.isNotEmpty()) originalHitFrames++
        original?.let { accumulate(it, original = true) }
        original?.let { accumulateContribution(it, level.appliedGain) }
        accumulate(translated, translated = true)
        accumulate(output, output = true)
        appliedGainSum += level.appliedGain
        minimumAppliedGain = minOf(minimumAppliedGain, level.appliedGain)
        maximumAppliedGain = maxOf(maximumAppliedGain, level.appliedGain)
        if (level.balanced) balancedFrames++
        if (level.gainLimited) gainLimitedFrames++
        if (translatedFrames < ReportEveryTranslatedFrames) return null
        val report = "translatedFrames=$translatedFrames originalHitFrames=$originalHitFrames " +
            "originalHitRate=${percent(originalHitFrames, translatedFrames)} " +
            "balancedFrames=$balancedFrames " +
            "targetOriginalRatioPercent=${(targetOriginalRatio * 100f).roundToInt()} " +
            "originalRmsDbfs=${dbfs(originalSquareSum, originalSamples)} " +
            "originalContributionRmsDbfs=" +
            "${dbfs(originalContributionSquareSum, originalContributionSamples)} " +
            "translatedRmsDbfs=${dbfs(translatedSquareSum, translatedSamples)} " +
            "outputRmsDbfs=${dbfs(outputSquareSum, outputSamples)} " +
            "appliedOriginalGainAvg=${gain(appliedGainSum / translatedFrames)} " +
            "appliedOriginalGainMin=${gain(minimumAppliedGain.toDouble())} " +
            "appliedOriginalGainMax=${gain(maximumAppliedGain.toDouble())} " +
            "gainLimitedFrames=$gainLimitedFrames " +
            "originalPeak=$originalPeak translatedPeak=$translatedPeak outputPeak=$outputPeak"
        reset()
        return report
    }

    private fun accumulateContribution(pcm: ShortArray, gain: Float) {
        originalContributionSquareSum += pcm.sumOf {
            val scaled = it.toDouble() * gain
            scaled * scaled
        }
        originalContributionSamples += pcm.size
    }

    private fun accumulate(
        pcm: ShortArray,
        original: Boolean = false,
        translated: Boolean = false,
        output: Boolean = false
    ) {
        val squareSum = pcm.sumOf { it.toDouble() * it.toDouble() }
        val peak = pcm.maxOfOrNull { kotlin.math.abs(it.toInt()) } ?: 0
        when {
            original -> {
                originalSquareSum += squareSum
                originalSamples += pcm.size
                originalPeak = maxOf(originalPeak, peak)
            }
            translated -> {
                translatedSquareSum += squareSum
                translatedSamples += pcm.size
                translatedPeak = maxOf(translatedPeak, peak)
            }
            output -> {
                outputSquareSum += squareSum
                outputSamples += pcm.size
                outputPeak = maxOf(outputPeak, peak)
            }
        }
    }

    private fun dbfs(squareSum: Double, samples: Int): String {
        if (samples == 0 || squareSum <= 0.0) return "-inf"
        val rms = kotlin.math.sqrt(squareSum / samples) / Short.MAX_VALUE
        return "%.1f".format(java.util.Locale.ROOT, 20.0 * kotlin.math.log10(rms))
    }

    private fun percent(part: Int, total: Int): Int =
        if (total == 0) 0 else part * 100 / total

    private fun gain(value: Double): String =
        "%.3f".format(java.util.Locale.ROOT, value)

    private fun reset() {
        translatedFrames = 0
        originalHitFrames = 0
        originalSquareSum = 0.0
        originalSamples = 0
        translatedSquareSum = 0.0
        translatedSamples = 0
        outputSquareSum = 0.0
        outputSamples = 0
        originalContributionSquareSum = 0.0
        originalContributionSamples = 0
        appliedGainSum = 0.0
        minimumAppliedGain = Float.POSITIVE_INFINITY
        maximumAppliedGain = Float.NEGATIVE_INFINITY
        balancedFrames = 0
        gainLimitedFrames = 0
        originalPeak = 0
        translatedPeak = 0
        outputPeak = 0
    }

    private companion object {
        const val ReportEveryTranslatedFrames = 50
    }
}
