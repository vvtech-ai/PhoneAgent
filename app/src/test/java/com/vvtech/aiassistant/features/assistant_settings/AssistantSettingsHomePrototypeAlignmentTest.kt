package com.vvtech.aiassistant.features.assistant_settings

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSettingsHomePrototypeAlignmentTest {
    @Test
    fun settingsHomeShowsRealtimeTranslationEntryAndKeepsDeferredContactWiring() {
        val source = settingsHomeSource()

        assertFalse(source.contains("title = \"联系方式\""))
        assertTrue(source.contains("R.string.settings_live_translation_original_audio_title"))
        assertTrue(source.contains("R.string.settings_live_translation_original_audio_description"))
        assertFalse(source.contains("title = \"实时翻译通话\""))
        assertFalse(source.contains("subtitle = \"模型、默认语种与原声播放\""))
        assertTrue(source.contains("R.string.settings_call_models_voices_title"))
        assertTrue(source.contains("R.string.settings_call_models_voices_description"))
        assertTrue(source.contains("R.string.settings_caller_profile_description"))
        assertTrue(source.contains("onOpenContactMethods: () -> Unit"))
        assertTrue(source.contains("onOpenTranslationProvider: () -> Unit"))
    }

    @Test
    fun originalAudioSettingsUsesRealtimeTranslationPageTitleAndKeepsSwitchLabel() {
        val source = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_translation/" +
                "DomesticTranslationAudioSettingsCard.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(source.contains("FinalBackTitleBar(title = \"实时翻译原音\""))
        assertTrue(source.contains("Text(\"播放原声\""))
    }

    @Test
    fun settingsTabMatchesPrototypeMcpVersionCopyAndHasNoBackButton() {
        val source = settingsHomeSource()

        assertTrue(source.contains("R.string.settings_trusted_call_mcp_title"))
        assertTrue(source.contains("R.string.settings_trusted_call_mcp_description"))
        assertTrue(source.contains("R.string.settings_software_update_title"))
        assertTrue(source.contains("R.string.settings_software_update_description"))
        assertTrue(source.contains("private fun SettingsHomeTitleBar"))
        assertFalse(source.contains("FinalBackTitleBar(title = \"设置\""))
        assertFalse(source.contains("onBack: () -> Unit"))
    }

    @Test
    fun settingsHomePlacesAppLanguageEntryBeforeSoftwareUpdate() {
        val source = settingsHomeSource()

        val languageIndex = source.indexOf("AppLanguageSettingCard")
        val versionIndex = source.indexOf("R.string.settings_software_update_title")

        assertTrue(languageIndex >= 0)
        assertTrue(versionIndex >= 0)
        assertTrue(languageIndex < versionIndex)
    }

    @Test
    fun settingsTitleIsLeftAlignedLikePrototype() {
        val titleBar = settingsHomeSource()
            .substringAfter("private fun SettingsHomeTitleBar(")
            .substringBefore("@Composable")

        assertTrue(titleBar.contains(".padding(horizontal = 24.dp, vertical = 8.dp)"))
        assertTrue(titleBar.contains("contentAlignment = Alignment.CenterStart"))
    }

    @Test
    fun settingsHomeUsesServerIdentityStatusInsteadOfNameBoolean() {
        val source = settingsHomeSource()

        assertTrue(source.contains("myIdentityStatus: AssistantIdentityProfileStatus"))
        assertTrue(source.contains("settingsIdentityStatusLabel(myIdentityStatus)"))
        assertFalse(source.contains("myIdentityHasName"))
    }

    @Test
    fun logoutUsesDedicatedTransparentRedCenteredTextInsteadOfGlobalDangerButton() {
        val settingsHome = settingsHomeSource()
        val sharedComponents = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalSharedComponents.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(settingsHome.contains("private fun SettingsLogoutAction"))
        assertTrue(settingsHome.contains("Color(0xFFEF4444)"))
        assertTrue(settingsHome.contains("FontWeight.Bold"))
        assertTrue(settingsHome.contains("contentAlignment = Alignment.Center"))
        assertFalse(settingsHome.contains("tone = FinalButtonTone.Danger"))
        assertTrue(sharedComponents.contains("FinalButtonTone.Danger -> Brush.verticalGradient"))
    }

    @Test
    fun settingsHomeReservesBottomNavigationHeightForLogoutAction() {
        val source = settingsHomeSource()

        assertTrue(
            source.contains(
                "contentPadding = PaddingValues(start = 10.dp, end = 10.dp, bottom = 128.dp)"
            )
        )
    }

    private fun settingsHomeSource(): String = File(
        "src/main/java/com/vvtech/aiassistant/features/assistant/FinalSettingsHomePage.kt"
    ).readText(Charsets.UTF_8)
}
