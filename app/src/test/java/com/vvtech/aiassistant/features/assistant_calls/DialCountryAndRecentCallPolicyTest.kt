package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.features.assistant.DialCallKind
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DialCountryAndRecentCallPolicyTest {
    @Test
    fun catalogKeepsOnlySupportedCountries() {
        assertEquals(listOf("CN", "JP", "SG", "US"), DialCountries.map { it.iso })
        assertEquals("+86", dialCountryByIso("CN").dialCode)
        assertEquals("+1", dialCountryByIso("US").dialCode)
    }

    @Test
    fun everySupportedCountryHasUniqueFlagAndUnknownIsoDoesNotFallbackToChina() {
        val resources = DialCountries.map { country ->
            requireNotNull(dialCountryFlagResource(country.iso)) {
                "Missing flag for ${country.iso}"
            }
        }

        assertEquals(DialCountries.size, resources.toSet().size)
        assertNull(dialCountryFlagResource("CA"))
        assertNull(dialCountryFlagResource(""))
    }

    @Test
    fun locatedSupportedCountryCanBeSelected() {
        assertEquals("JP", resolveLocatedDialCountry("jp")?.iso)
        assertNull(resolveLocatedDialCountry("CA"))
        assertNull(resolveLocatedDialCountry(null))
    }

    @Test
    fun countrySearchSupportsChinesePinyinInitialsAndDialCode() {
        assertEquals(listOf("CN"), searchedCountryIsos("中国"))
        assertEquals(listOf("CN"), searchedCountryIsos("zhongguo"))
        assertEquals(listOf("SG"), searchedCountryIsos("xjp"))
        assertEquals(listOf("JP"), searchedCountryIsos("+81"))
    }

    @Test
    fun countryAlphabetIndexContainsOnlyExistingSections() {
        val sections = dialCountryAlphabetSections(buildDialCountryListItems(""))

        assertEquals(listOf("G20", "C", "J", "S", "U"), sections)
    }

    @Test
    fun dialTargetKeepsLeadingInternationalPlus() {
        assertEquals("+819012345678", normalizeDialTarget("+81 90-1234-5678"))
        assertEquals("006581234567", normalizeDialTarget("0065 8123 4567"))
    }

    @Test
    fun recentCallsKeepOnlyNormalAndTranslationNewestTwenty() {
        val records = buildList {
            add(record(100, DialCallKind.AGENT))
            repeat(12) { add(record(it.toLong(), DialCallKind.NORMAL)) }
            repeat(12) { add(record((50 + it).toLong(), DialCallKind.TRANSLATION)) }
        }

        val recent = dialRecentCallRecords(records)

        assertEquals(20, recent.size)
        assertEquals((61L downTo 50L).toList() + (11L downTo 4L).toList(), recent.map { it.occurredAtMillis })
        assertEquals(false, recent.any { it.callKind == DialCallKind.AGENT })
    }

    @Test
    fun duplicateRecentNumbersAreNotMerged() {
        val records = listOf(
            record(2, DialCallKind.NORMAL),
            record(1, DialCallKind.TRANSLATION)
        )

        assertEquals(listOf(2L, 1L), dialRecentCallRecords(records).map { it.occurredAtMillis })
    }

    @Test
    fun recentCallPrefersContactNameMatchedByNumber() {
        val contacts = listOf(
            DialContactEntry("1", "张三", "+86 188 2318 9131", emptyList())
        )
        val matched = localDialRecentCalls(
            listOf(record(2, DialCallKind.NORMAL).copy(phoneNumber = "18823189131")),
            contacts
        )

        assertEquals("张三", matched.single().displayName)
        assertEquals("JP", matched.single().countryIso)
        assertEquals("zh", matched.single().callerLanguageCode)
        assertEquals("ja", matched.single().calleeLanguageCode)
    }

    @Test
    fun recentCallRestoresCountryCodeFromSnapshotWithoutDuplicatingInternationalPrefix() {
        val nationalUs = localDialRecentCalls(
            listOf(
                record(3, DialCallKind.TRANSLATION).copy(
                    phoneNumber = "5023258388",
                    dialCountryIso = "US"
                )
            )
        ).single()
        val internationalJapan = localDialRecentCalls(
            listOf(
                record(2, DialCallKind.TRANSLATION).copy(
                    phoneNumber = "+819012345678",
                    dialCountryIso = "JP"
                )
            )
        ).single()
        val legacyNational = localDialRecentCalls(
            listOf(
                record(1, DialCallKind.NORMAL).copy(
                    phoneNumber = "5023258388",
                    dialCountryIso = ""
                )
            )
        ).single()

        assertEquals("+15023258388", nationalUs.phoneNumber)
        assertEquals("+1 502 325 8388", formatDialHistoryNumberForDisplay(nationalUs.phoneNumber))
        assertEquals("+819012345678", internationalJapan.phoneNumber)
        assertEquals("5023258388", legacyNational.phoneNumber)
    }

    private fun searchedCountryIsos(query: String): List<String> =
        buildDialCountryListItems(query).mapNotNull {
            (it as? DialCountryListItem.Country)?.value?.iso
        }

    private fun record(time: Long, kind: DialCallKind) = FinalCallRecord(
        title = "拨打 10086",
        status = kind.name,
        meta = "刚刚",
        success = true,
        occurredAtMillis = time,
        phoneNumber = "10086",
        callKind = kind,
        dialCountryIso = "JP",
        callerLanguageCode = "zh",
        calleeLanguageCode = "ja"
    )
}
