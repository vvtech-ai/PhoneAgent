package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSettingsNavigationActionsTest {
    @Test
    fun settingsEntriesOpenExpectedSubPages() {
        val recorder = SettingsNavigationRecorder()

        openAssistantSettings(recorder.callbacks)
        openAssistantDeveloperTools(recorder.callbacks)
        openAssistantContactMethods(recorder.callbacks)
        openAssistantMyIdentity(recorder.callbacks)
        openAssistantSipAccountSettings(recorder.callbacks)
        openAssistantRealtimeProviderSettings(recorder.callbacks)
        openAssistantTranslationProviderSettings(recorder.callbacks)
        openAssistantVoiceIdentitySettings(recorder.callbacks)
        openAssistantOutboundNumberEdit(recorder.callbacks)

        assertEquals(
            listOf(
                "sub:Settings",
                "sub:DeveloperTools",
                "sub:ContactMethods",
                "sub:MyIdentity",
                "sub:SipAccountSettings",
                "sub:RealtimeProviderSettings",
                "sub:TranslationProviderSettings",
                "sub:VoiceIdentitySettings",
                "sub:OutboundNumberEdit"
            ),
            recorder.events
        )
    }

    @Test
    fun myIdentityVoiceCloneEntryRefreshesAndOpensVoiceModelSettings() {
        val path =
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/" +
                "AssistantRootPageHostMainArgsFactory.kt"
        val source = listOf(File(path), File("android/app/$path"))
            .first { it.exists() }
            .readText(Charsets.UTF_8)

        assertTrue(source.contains("runtime.provider.refreshRealtimeCallProvider(force = true)"))
        assertTrue(source.contains("callbacks.onOpenSubPage(FinalPage.RealtimeProviderSettings)"))
        assertFalse(source.contains("runtime.voiceClone.openFlow()"))
    }

    @Test
    fun settingsReturnsNavigateToExpectedPages() {
        val recorder = SettingsNavigationRecorder()

        returnToAssistantSettings(recorder.callbacks)
        returnToAssistantVoiceIdentitySettings(recorder.callbacks)
        returnToAssistantDeveloperTools(recorder.callbacks)

        assertEquals(
            listOf(
                "page:Settings",
                "page:VoiceIdentitySettings",
                "page:DeveloperTools"
            ),
            recorder.events
        )
    }

    @Test
    fun sipSettingsEntryReturnsToSettingsWhenRegionHidesSip() {
        val recorder = SettingsNavigationRecorder()

        openAssistantSipAccountSettings(
            callbacks = recorder.callbacks,
            allowedByRegion = false
        )

        assertEquals(listOf("page:Settings"), recorder.events)
    }
}

private class SettingsNavigationRecorder {
    val events = mutableListOf<String>()

    val callbacks = AssistantSettingsNavigationCallbacks(
        onPageChange = { page ->
            events += "page:${page.name}"
        },
        onOpenSubPage = { page ->
            events += "sub:${page.name}"
        }
    )
}
