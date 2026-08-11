package com.vvtech.aiassistant.features.assistant

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FinalCallRecordStorageTest {

    @Test
    fun storageKeyIsScopedByAccountId() {
        assertEquals("final_call_records_phone-13800138000", finalCallRecordsStorageKey("phone-13800138000"))
        assertEquals("final_call_records_phone-13900139000", finalCallRecordsStorageKey("phone-13900139000"))
        assertEquals("final_call_records_guest", finalCallRecordsStorageKey(""))
    }

    @Test
    fun encodeAndDecodePreserveCallRecords() {
        val raw = encodeFinalCallRecords(
            listOf(
                FinalCallRecord(
                    title = "翻译通话 138 0013 8000",
                    status = "实时翻译通话",
                    meta = "刚刚 · 实时翻译通话结束，时长 00:12",
                    success = true,
                    occurredAtMillis = 1_746_000_000_000L,
                    callKind = DialCallKind.TRANSLATION,
                    dialCountryIso = "JP",
                    callerLanguageCode = "zh",
                    calleeLanguageCode = "ja"
                ),
                FinalCallRecord(
                    title = "拨打 139 0013 9000",
                    status = "普通通话",
                    meta = "刚刚 · 普通通话结束，时长 03:12",
                    success = true,
                    occurredAtMillis = 1_746_000_010_000L,
                    callKind = DialCallKind.NORMAL
                )
            )
        )

        val decoded = decodeFinalCallRecords(raw)

        assertEquals(2, decoded.size)
        assertEquals("翻译通话 138 0013 8000", decoded[0].title)
        assertEquals("实时翻译通话", decoded[0].status)
        assertEquals("刚刚 · 实时翻译通话结束，时长 00:12", decoded[0].meta)
        assertEquals(1_746_000_000_000L, decoded[0].occurredAtMillis)
        assertEquals(DialCallKind.TRANSLATION, decoded[0].callKind)
        assertEquals("JP", decoded[0].dialCountryIso)
        assertEquals("zh", decoded[0].callerLanguageCode)
        assertEquals("ja", decoded[0].calleeLanguageCode)
        assertEquals("拨打 139 0013 9000", decoded[1].title)
        assertEquals(1_746_000_010_000L, decoded[1].occurredAtMillis)
        assertEquals(DialCallKind.NORMAL, decoded[1].callKind)
    }

    @Test
    fun decodeIgnoresBrokenEntries() {
        val decoded = decodeFinalCallRecords(
            """
                [
                  {"title":"翻译通话 138 0013 8000","status":"实时翻译通话","meta":"刚刚 · 实时翻译通话结束，时长 00:12","success":true,"occurredAtMillis":1746000000000},
                  {"title":"","status":"普通通话","meta":"缺少标题"},
                  {"status":"普通通话","meta":"缺少标题"}
                ]
            """.trimIndent()
        )

        assertEquals(1, decoded.size)
        assertTrue(decoded.first().success)
        assertEquals(DialCallKind.AGENT, decoded.first().callKind)
        assertEquals("", decoded.first().dialCountryIso)
        assertEquals("", decoded.first().callerLanguageCode)
        assertEquals("", decoded.first().calleeLanguageCode)
    }
}
