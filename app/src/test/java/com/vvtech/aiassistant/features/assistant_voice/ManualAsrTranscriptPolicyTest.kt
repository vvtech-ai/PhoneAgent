package com.vvtech.aiassistant.features.assistant_voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ManualAsrTranscriptPolicyTest {

    @Test
    fun releaseTranscriptMergesBufferedFinalWithRawFallbackPartial() {
        val result = resolveManualAsrReleaseTranscript(
            bufferedFinal = "帮我订今晚七点的海底捞，八个人。",
            fallback = "要包房"
        )

        assertEquals("帮我订今晚七点的海底捞，八个人。 要包房", result.text)
        assertTrue(result.fallbackAddsBufferedContent)
    }

    @Test
    fun releaseTranscriptKeepsFallbackThatAlreadyContainsBufferedFinal() {
        val result = resolveManualAsrReleaseTranscript(
            bufferedFinal = "帮我订今晚七点的海底捞，八个人。",
            fallback = "帮我订今晚七点的海底捞，八个人。要包房"
        )

        assertEquals("帮我订今晚七点的海底捞，八个人。要包房", result.text)
        assertTrue(result.fallbackAddsBufferedContent)
    }

    @Test
    fun releaseTranscriptMergesOverlappingFallbackPrefix() {
        val result = resolveManualAsrReleaseTranscript(
            bufferedFinal = "帮我订今晚七点的海底捞",
            fallback = "海底捞八个人要包房"
        )

        assertEquals("帮我订今晚七点的海底捞八个人要包房", result.text)
        assertTrue(result.fallbackAddsBufferedContent)
    }

    @Test
    fun releaseTranscriptDoesNotDuplicateSameOrSuffixFallback() {
        val same = resolveManualAsrReleaseTranscript(
            bufferedFinal = "这是测试。",
            fallback = "这是测试。"
        )
        val suffix = resolveManualAsrReleaseTranscript(
            bufferedFinal = "这是测试。",
            fallback = "测试。"
        )

        assertEquals("这是测试。", same.text)
        assertFalse(same.fallbackAddsBufferedContent)
        assertEquals("这是测试。", suffix.text)
        assertFalse(suffix.fallbackAddsBufferedContent)
    }
}
