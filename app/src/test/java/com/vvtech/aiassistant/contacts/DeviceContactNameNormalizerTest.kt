package com.vvtech.aiassistant.contacts

import android.app.Application
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], application = Application::class)
class DeviceContactNameNormalizerTest {
    private val normalize = DeviceContactNameNormalizer()::normalize

    @Test
    fun typedNamesOnlyIgnoreOuterSpacesChineseVariantAndEnglishCase() {
        assertTrue(typedContactNamesMatch("  張三  ", "张三", normalize))
        assertTrue(typedContactNamesMatch("andre smith", "Andre Smith", normalize))
        assertFalse(typedContactNamesMatch("Andre  Smith", "Andre Smith", normalize))
        assertFalse(typedContactNamesMatch("张三", "章三", normalize))
        assertFalse(typedContactNamesMatch("张", "小张", normalize))
    }

    @Test
    fun asrPinyinIndexMatchesSimplifiedQueryToTraditionalContact() {
        val traditionalEntry = PinyinContactEntry(
            displayName = "龍芳",
            phoneNumber = "13800138000",
            namePinyin = ContactPinyinTokenizer.toPinyinTokens(normalize("龍芳"))
        )

        val results = ContactPinyinSearchEngine().search("龙芳", listOf(traditionalEntry))

        assertEquals(listOf("龍芳"), results.map { it.entry.displayName })
    }
}
