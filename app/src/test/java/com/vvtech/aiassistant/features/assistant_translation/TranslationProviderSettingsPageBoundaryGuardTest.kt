package com.vvtech.aiassistant.features.assistant_translation

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationProviderSettingsPageBoundaryGuardTest {
    @Test
    fun domesticOriginalAudioPageDoesNotReadOrSwitchRemoteProvider() {
        val host = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/translation_call/ui/screen/TranslationCallSettingsHosts.kt"
        ).readText(Charsets.UTF_8)

        val domesticBranch = host
            .substringAfter("visibility.showDomesticProvider ->")
            .substringBefore("else ->")

        assertTrue(domesticBranch.contains("DomesticOriginalAudioSettingsPage("))
        assertTrue(domesticBranch.contains("holder::setPlayOriginalAudio"))
        assertTrue(domesticBranch.contains("holder::setOriginalAudioGainPercent"))
        assertTrue(domesticBranch.contains("holder::setOriginalAudioVolumePercent"))
        assertFalse(domesticBranch.contains("translationProviderResponse"))
        assertFalse(domesticBranch.contains("onSwitchTranslationProvider"))
        assertFalse(host.contains("confirmedDomesticProvider"))
    }

    @Test
    fun domesticOriginalAudioLevelsAreReachableAndDiscrete() {
        val card = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_translation/DomesticTranslationAudioSettingsCard.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(card.contains("DomesticOriginalAudioSettingsState"))
        assertTrue(card.contains("纯原声播放声音大小"))
        assertTrue(card.contains("混声时原声比例"))
        assertTrue(card.contains("maxPercent = 100"))
        assertTrue(card.contains("maxPercent = 50"))
        assertTrue(card.contains("steps = 9"))
        assertTrue(card.contains("steps = 4"))
        assertTrue(card.contains("enabled = state.enabled"))
        assertTrue(card.contains("仅影响下一通实时翻译通话"))
    }

    @Test
    fun providerSettingsPageBodyStaysInTranslationBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalSettingsPage.kt")
        val pageFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_translation/AssistantTranslationProviderSettingsPage.kt"
        )
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val page = pageFile.readText(Charsets.UTF_8)

        assertTrue("FinalSettingsPage should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 120)
        assertTrue("Translation provider settings page must stay below the new-file guard threshold.", pageFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy translation provider entry should delegate to the translation boundary.",
            legacy.contains("import com.vvtech.aiassistant.features.assistant_translation.AssistantTranslationProviderSettingsPage") &&
                legacy.contains("internal fun FinalTranslationProviderPageV3Safe(") &&
                legacy.contains("AssistantTranslationProviderSettingsPage(")
        )
        forbiddenLegacyTokens.forEach { token ->
            assertFalse("Provider settings page body must not return to FinalSettingsPage: $token", legacy.contains(token))
        }
        assertTrue(
            "Provider settings page body should live in assistant_translation.",
            page.contains("internal fun AssistantTranslationProviderSettingsPage(") &&
                page.contains("items(providerResponse?.providers.orEmpty()") &&
                page.contains("DomesticTranslationAudioSettingsCard(") &&
                page.contains("onSelectProvider(provider.provider)")
        )
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Translation provider settings UI must not depend on runtime/business dependency: $dependency",
                page.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyTokens = listOf(
            "items(providerResponse?.providers.orEmpty()",
            "val qwenSelected = activeProvider ==",
            "TranslationLanguagePicker(",
            "onSelectProvider(provider.provider)",
            "Qwen \\u6a21\\u578b\\u4e0b"
        )

        val bannedRuntimeDependencies = listOf(
            "Repository",
            "AssistantContainer",
            "AppContainer",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "AudioTrack",
            "MediaPlayer",
            "Asr",
            "Tts",
            "SIP",
            "AgentStream"
        )

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
