package com.vvtech.aiassistant.features.assistant_calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DialContactSuggestionPolicyTest {
    @Test
    fun t9NameMatchesAreOrderedBeforeNumberMatches() {
        val contacts = listOf(
            contact("1", "王小明", "+8613800100200", "WANG", "XIAO", "MING"),
            contact("2", "号码命中", "+8613999601234", "HAO", "MA", "MING", "ZHONG")
        )

        val result = dialContactSuggestions("996", contacts)

        assertEquals(listOf("王小明", "号码命中"), result.map { it.displayName })
        assertEquals(DialContactMatchKind.NAME, result[0].matchKind)
        assertEquals(DialContactMatchKind.NUMBER, result[1].matchKind)
        assertNull(result[0].numberHitStart)
        assertEquals(3, result[1].numberHitStart)
        assertEquals(6, result[1].numberHitEndExclusive)
    }

    @Test
    fun fullPinyinT9PrefixCanMatchName() {
        val result = dialContactSuggestions(
            query = "9264",
            contacts = listOf(contact("1", "王小明", "13800100200", "WANG", "XIAO", "MING"))
        )

        assertEquals(1, result.size)
        assertEquals(DialContactMatchKind.NAME, result.single().matchKind)
    }

    @Test
    fun nameMatchUsesFirstPhoneAndNumberMatchKeepsMatchedPhone() {
        val contacts = listOf(
            contact("1", "王小明", "13800100200", "WANG", "XIAO", "MING"),
            contact("1", "王小明", "13900009960", "WANG", "XIAO", "MING"),
            contact("2", "李雷", "13899601234", "LI", "LEI")
        )

        val result = dialContactSuggestions("996", contacts)

        assertEquals(2, result.size)
        assertEquals("13800100200", result[0].phoneNumber)
        assertEquals("13899601234", result[1].phoneNumber)
    }

    @Test
    fun formattedHighlightRangeSkipsSpacesAndCountryPrefix() {
        assertEquals(
            8..10,
            formattedDigitHighlightRange(
                formattedNumber = "+86 139 9960 1234",
                rawDigitStart = 3,
                rawDigitEndExclusive = 6
            )
        )
        assertNull(formattedDigitHighlightRange("+86 139 9960 1234", null, null))
    }

    @Test
    fun specialDialCharactersDoNotTriggerT9AndResultsAreLimited() {
        val contacts = (1..12).map {
            contact(it.toString(), "王小明$it", "1380010${it.toString().padStart(4, '0')}", "WANG")
        }

        assertTrue(dialContactSuggestions("*996", contacts).isEmpty())
        assertEquals(10, dialContactSuggestions("9", contacts).size)
    }

    private fun contact(
        id: String,
        name: String,
        phone: String,
        vararg pinyin: String
    ) = DialContactEntry(
        contactId = id,
        displayName = name,
        phoneNumber = phone,
        pinyinTokens = pinyin.toList()
    )
}
