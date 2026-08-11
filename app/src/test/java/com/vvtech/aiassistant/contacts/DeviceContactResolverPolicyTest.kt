package com.vvtech.aiassistant.contacts

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceContactResolverPolicyTest {

    @Test
    fun extractCallContactCandidateNamesSupportsMultipleContacts() {
        val names = DeviceContactPolicy.extractCallContactCandidateNames(
            "\u5e2e\u6211\u8054\u7cfb\u5f20\u4e09\u548c\u674e\u56db\u6253\u7535\u8bdd"
        )

        assertEquals(listOf("\u5f20\u4e09", "\u674e\u56db"), names)
        assertEquals(names, DeviceContactResolver.extractCallContactCandidateNames(
            "\u5e2e\u6211\u8054\u7cfb\u5f20\u4e09\u548c\u674e\u56db\u6253\u7535\u8bdd"
        ))
    }

    @Test
    fun extractExplicitContactReadsNameAndMainlandMobile() {
        val contact = DeviceContactPolicy.extractExplicitContact(
            "\u8054\u7cfb\u4eba\u5f20\u4e09\uff0c\u7535\u8bdd\u662f13800138000"
        )

        assertEquals("\u5f20\u4e09", contact?.contactName)
        assertEquals("13800138000", contact?.phoneNumber)
        assertEquals(contact, DeviceContactResolver.extractExplicitContact(
            "\u8054\u7cfb\u4eba\u5f20\u4e09\uff0c\u7535\u8bdd\u662f13800138000"
        ))
    }

    @Test
    fun extractExplicitContactRejectsInvalidOrMissingMobile() {
        assertNull(DeviceContactPolicy.extractExplicitContact("\u5f20\u4e09\u7684\u7535\u8bdd\u662f12345"))
        assertNull(DeviceContactPolicy.extractExplicitContact("13800138000"))
    }

    @Test
    fun normalizeDeviceContactPhoneKeepsSupportedDialShapes() {
        assertEquals("13800138000", DeviceContactPolicy.normalizePhone("+86 138 0013 8000"))
        assertEquals("01012345678-123", DeviceContactPolicy.normalizePhone("010-12345678 ext.123"))
        assertEquals("4001234567", DeviceContactPolicy.normalizePhone("400-123-4567"))
        assertEquals("12345678", DeviceContactPolicy.normalizePhone("1234 5678"))
        assertEquals("13800138000", DeviceContactResolver.normalizeDeviceContactPhone("+86 138 0013 8000"))
    }

    @Test
    fun normalizeDeviceContactPhoneRejectsBlankAndNonNumericValues() {
        assertEquals("", DeviceContactPolicy.normalizePhone(""))
        assertEquals("", DeviceContactPolicy.normalizePhone("abc"))
    }

    @Test
    fun contactTextAndPhonePolicyStayOutsideResolver() {
        val resolver = sourceFile(
            "src/main/java/com/vvtech/aiassistant/contacts/DeviceContactResolver.kt"
        ).readText(Charsets.UTF_8)
        val policy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/contacts/DeviceContactPolicy.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(policy.contains("internal object DeviceContactPolicy"))
        assertTrue(resolver.contains("DeviceContactPolicy.normalizePhone"))
        assertTrue(resolver.contains("DeviceContactPolicy.extractCallContactCandidateNames"))
        assertTrue(resolver.contains("DeviceContactPolicy.extractExplicitContact"))
        assertFalse(resolver.contains("private val mobilePattern"))
        assertFalse(resolver.contains("private val callKeywords"))
        assertFalse(resolver.contains("multiContactPattern = Regex"))
        assertFalse(resolver.contains("contactNameSeparatorPattern"))
        assertFalse(resolver.contains("private fun String.normalizePhone"))
    }

    @Test
    fun systemContactsQueryStaysInDataSource() {
        val resolver = sourceFile(
            "src/main/java/com/vvtech/aiassistant/contacts/DeviceContactResolver.kt"
        ).readText(Charsets.UTF_8)
        val dataSource = sourceFile(
            "src/main/java/com/vvtech/aiassistant/contacts/DeviceContactDataSource.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(resolver.lines().size < 360)
        assertTrue(dataSource.lines().size <= 140)
        assertTrue(resolver.contains("private val dataSource = DeviceContactDataSource(context)"))
        assertTrue(resolver.contains("dataSource.loadPhoneRows()"))
        assertTrue(resolver.contains("dataSource.findRowsByDisplayNameExact"))
        assertTrue(resolver.contains("dataSource.findRowsByDisplayNameLike"))

        listOf(
            "contentResolver.query",
            "ContactsContract.CommonDataKinds.Phone.CONTENT_URI",
            "ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME",
            "getColumnIndex(",
            "while (cursor.moveToNext())",
            "Projection = arrayOf"
        ).forEach { token ->
            assertFalse("resolver should not own system contacts query: $token", resolver.contains(token))
            assertTrue("datasource should own system contacts query: $token", dataSource.contains(token))
        }

        listOf(
            "ViewModel",
            "Repository",
            "AgentStream",
            "TaskVoice",
            "Asr",
            "Tts",
            "SIP",
            "Composable"
        ).forEach { token ->
            assertFalse("datasource should not depend on runtime/UI: $token", dataSource.contains(token))
        }
    }

    @Test
    fun candidateLookupStaysInUseCase() {
        val resolver = sourceFile(
            "src/main/java/com/vvtech/aiassistant/contacts/DeviceContactResolver.kt"
        ).readText(Charsets.UTF_8)
        val useCase = sourceFile(
            "src/main/java/com/vvtech/aiassistant/contacts/DeviceContactCandidateLookupUseCase.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(resolver.contains("DeviceContactCandidateLookupUseCase("))
        assertTrue(resolver.contains("candidateLookupUseCase.findCandidatesByDisplayNames(contactNames, allowFuzzyMatching)"))
        assertTrue(resolver.contains("candidateLookupUseCase.clearCache()"))

        listOf(
            "CandidatesCacheEntry",
            "lookupCandidatesForName(",
            "runPinyinFallbackQuery(",
            "ContactPinyinSearchEngine().search",
            "MULTIPLE_CANDIDATES"
        ).forEach { token ->
            assertFalse("resolver should not own candidate lookup: $token", resolver.contains(token))
            assertTrue("use case should own candidate lookup: $token", useCase.contains(token))
        }

        assertTrue(useCase.lines().size < 300)
        assertFalse(useCase.contains("Context"))
        assertFalse(useCase.contains("ContentResolver"))
        assertFalse(useCase.contains("ContactsContract"))
    }

    @Test
    fun singlePinyinFallbackCandidateRequiresSelection() {
        assertEquals(
            "MULTIPLE_CANDIDATES",
            resolveDeviceContactLookupStatus(candidateCount = 1, matchType = "pinyin_fallback")
        )
        assertEquals(
            "RESOLVED",
            resolveDeviceContactLookupStatus(candidateCount = 1, matchType = "name_exact")
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).firstOrNull { it.exists() } ?: error("Missing source file: $path")
        }
    }
}
