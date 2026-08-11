package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DialRecentCallMergePolicyTest {
    @Test
    fun systemAndSipRecordsAreMergedNewestFirst() {
        val system = listOf(
            recent("system-1", 100L, DialRecentCallSource.SYSTEM, DialRecentCallKind.NORMAL)
        )
        val sip = listOf(
            recent("sip-translation", 300L, DialRecentCallSource.SIP, DialRecentCallKind.TRANSLATION),
            recent("sip-normal", 200L, DialRecentCallSource.SIP, DialRecentCallKind.NORMAL),
            recent("agent", 400L, DialRecentCallSource.LOCAL_AGENT, DialRecentCallKind.AGENT)
        )

        val result = mergeDialRecentCalls(system, sip)

        assertEquals(listOf("sip-translation", "system-1"), result.map { it.id })
        assertTrue(result.none { it.kind == DialRecentCallKind.AGENT })
    }

    @Test
    fun duplicatedSourceRecordIsShownOnce() {
        val duplicated = recent(
            "sip-1",
            100L,
            DialRecentCallSource.SIP,
            DialRecentCallKind.TRANSLATION
        )

        assertEquals(1, mergeDialRecentCalls(listOf(duplicated), listOf(duplicated)).size)
    }

    @Test
    fun onlyTranslationRecordHasTypeLabel() {
        assertEquals("实时翻译", dialHistoryTypeLabel(DialRecentCallKind.TRANSLATION))
        assertNull(dialHistoryTypeLabel(DialRecentCallKind.NORMAL))
        assertNull(dialHistoryTypeLabel(DialRecentCallKind.AGENT))
    }

    @Test
    fun mergedTimelineIsLimitedToNewestTwentyRecords() {
        val system = (1L..15L).map {
            recent("system-$it", it, DialRecentCallSource.SYSTEM, DialRecentCallKind.NORMAL)
        }
        val translations = (16L..25L).map {
            recent("translation-$it", it, DialRecentCallSource.SIP, DialRecentCallKind.TRANSLATION)
        }

        val result = mergeDialRecentCalls(system, translations, MaxDialRecentCalls)

        assertEquals(20, result.size)
        assertEquals("translation-25", result.first().id)
        assertEquals("system-6", result.last().id)
    }

    @Test
    fun `click action only fills input for normal and translation records`() {
        val serviceNumber = "4001234567"
        val normal = recent(
            "normal",
            1L,
            DialRecentCallSource.SYSTEM,
            DialRecentCallKind.NORMAL,
            serviceNumber
        )
        val translation = recent(
            "translation",
            2L,
            DialRecentCallSource.SIP,
            DialRecentCallKind.TRANSLATION,
            serviceNumber
        )

        assertEquals(DialRecentCallClickAction.FILL_INPUT, dialRecentCallClickAction(normal))
        assertEquals(DialRecentCallClickAction.FILL_INPUT, dialRecentCallClickAction(translation))
    }

    private fun recent(
        id: String,
        time: Long,
        source: DialRecentCallSource,
        kind: DialRecentCallKind,
        phoneNumber: String = "13812345678"
    ) = DialRecentCall(
        id = id,
        phoneNumber = phoneNumber,
        displayName = "",
        startedAtMillis = time,
        durationSeconds = 12,
        direction = DialRecentCallDirection.OUTGOING,
        status = DialRecentCallStatus.COMPLETED,
        source = source,
        kind = kind
    )
}
