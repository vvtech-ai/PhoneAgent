package com.vvtech.aiassistant.contacts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContactPinyinSearchEngineTest {

    private val engine = ContactPinyinSearchEngine()

    @Test
    fun search_matchesChineseNameBySeparatedPinyin() {
        val results = engine.search(
            "zhang san",
            listOf(entry("\u5f20\u4e09", "13800138000"))
        )

        assertEquals(1, results.size)
        assertEquals("\u5f20\u4e09", results[0].entry.displayName)
        assertEquals("FULL_PINYIN", results[0].matchKind)
    }

    @Test
    fun search_splitsContinuousLatinPinyinByKnownContactSyllables() {
        val results = engine.search(
            "zhangsan",
            listOf(entry("\u5f20\u4e09", "13800138000"))
        )

        assertEquals(1, results.size)
        assertEquals("\u5f20\u4e09", results[0].entry.displayName)
    }

    @Test
    fun search_matchesChineseHomophoneByPinyin() {
        val results = engine.search(
            "\u5f20\u4e09",
            listOf(entry("\u7ae0\u4e09", "13800138000"))
        )

        assertEquals(1, results.size)
        assertEquals("\u7ae0\u4e09", results[0].entry.displayName)
    }

    @Test
    fun search_prefersExactPinyinOverFuzzyPinyin() {
        val results = engine.search(
            "zhang san",
            listOf(
                entry("\u5f20\u4e09", "13800138000"),
                entry("\u81e7\u4e09", "13800138001")
            )
        )

        assertEquals("\u5f20\u4e09", results.first().entry.displayName)
        assertTrue(results[0].score > results[1].score)
    }

    @Test
    fun search_appliesYunmuFuzzyMatch() {
        val results = engine.search(
            "lin",
            listOf(entry("\u51cc", "13800138000"))
        )

        assertEquals(1, results.size)
        assertEquals("\u51cc", results[0].entry.displayName)
    }

    @Test
    fun search_appliesShengmuFuzzyMatch() {
        val results = engine.search(
            "zang",
            listOf(entry("\u5f20", "13800138000"))
        )

        assertEquals(1, results.size)
        assertEquals("\u5f20", results[0].entry.displayName)
    }

    @Test
    fun search_supportsLastTwoSyllablesForLongNames() {
        val results = engine.search(
            "xiao ming",
            listOf(entry("\u6b27\u9633\u5c0f\u660e", "13800138000"))
        )

        assertEquals(1, results.size)
        assertEquals("LAST_TWO_PINYIN", results[0].matchKind)
    }

    @Test
    fun search_rejectsQueriesLongerThanFourSyllables() {
        val results = engine.search(
            "yi er san si wu",
            listOf(
                PinyinContactEntry(
                    displayName = "Long Name",
                    phoneNumber = "13800138000",
                    namePinyin = listOf("YI", "ER", "SAN", "SI", "WU")
                )
            )
        )

        assertTrue(results.isEmpty())
    }

    private fun entry(name: String, phone: String): PinyinContactEntry =
        PinyinContactEntry(displayName = name, phoneNumber = phone)
}
