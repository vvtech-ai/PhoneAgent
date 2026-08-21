package com.vvtech.aiassistant.features.assistant_settings

import com.vvtech.aiassistant.features.assistant_i18n.AppLanguage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AssistantSipAccountOptionsTest {
    @Test
    fun publicCatalogDelegatesAccountSelectionToBackend() {
        assertEquals(listOf("auto"), AssistantDomesticSipAccountOptions.map(AssistantSipAccountOption::id))
        assertEquals(listOf("auto"), AssistantInternationalSipAccountOptions.map(AssistantSipAccountOption::id))
        assertEquals("后台自动分配", domesticSipAccountLabel("auto"))
        assertEquals("后台自动分配", internationalSipAccountLabel("auto"))
    }

    @Test
    fun publicCatalogShowsBackendAssignedCopyInEnglish() {
        assertEquals("Assigned by server", domesticSipAccountLabel("auto", AppLanguage.English))
        assertEquals("Assigned by server", internationalSipAccountLabel("auto", AppLanguage.English))
    }

    @Test
    fun unknownIdsFallBackToAiphoneDefaults() {
        assertEquals(DefaultDomesticSipAccountId, normalizeDomesticSipAccountId("missing"))
        assertEquals(DefaultInternationalSipAccountId, normalizeInternationalSipAccountId("missing"))
        assertEquals(DefaultDomesticSipAccountId, normalizeDomesticSipAccountId(null))
        assertEquals(DefaultInternationalSipAccountId, normalizeInternationalSipAccountId(null))
    }

    @Test
    fun settingsUiDoesNotContainSipCredentialFields() {
        val source = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_settings/" +
                "AssistantSipAccountSettingsPage.kt"
        ).readText(Charsets.UTF_8)

        assertFalse(source.contains("password", ignoreCase = true))
        assertFalse(source.contains("server", ignoreCase = true))
    }

    private fun sourceFile(path: String): File = listOf(
        File(path),
        File("android/app/$path")
    ).first { it.exists() }
}
