package com.vvtech.aiassistant.features.assistant_i18n

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppLanguageTest {
    @Test
    fun storedLanguageTagReturnsNullWhenNoAppLocaleWasPersisted() {
        assertNull(AppLanguage.fromStoredLanguageTagOrNull(""))
        assertNull(AppLanguage.fromStoredLanguageTagOrNull(" "))
        assertNull(AppLanguage.fromStoredLanguageTagOrNull(null))
    }

    @Test
    fun storedLanguageTagResolvesSupportedLanguagesOnly() {
        assertEquals(AppLanguage.English, AppLanguage.fromStoredLanguageTagOrNull("en"))
        assertEquals(AppLanguage.SimplifiedChinese, AppLanguage.fromStoredLanguageTagOrNull("zh-CN"))
        assertNull(AppLanguage.fromStoredLanguageTagOrNull("fr"))
    }
}
