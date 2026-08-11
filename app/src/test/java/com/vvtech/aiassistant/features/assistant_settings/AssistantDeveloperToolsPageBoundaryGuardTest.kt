package com.vvtech.aiassistant.features.assistant_settings

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantDeveloperToolsPageBoundaryGuardTest {
    @Test
    fun developerToolsPageBodyStaysInSettingsBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalDeveloperToolsPage.kt")
        val pageFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_settings/AssistantDeveloperToolsPage.kt"
        )
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val page = pageFile.readText(Charsets.UTF_8)
        val argsBuilder = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantPageHostArgsBuilder.kt"
        ).readText(Charsets.UTF_8)
        val argsFactory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostSecondaryArgsFactory.kt"
        ).readText(Charsets.UTF_8)

        assertTrue("FinalDeveloperToolsPage should stay below 300 lines after page body migration.", legacyFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue("AssistantDeveloperToolsPage must stay below the new-file guard threshold.", pageFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy developer tools entry should delegate to the settings boundary.",
            legacy.contains("import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPage") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_settings.AssistantDeveloperToolsPageArgs") &&
                legacy.contains("internal fun FinalDeveloperToolsPageV3(") &&
                legacy.contains("AssistantDeveloperToolsPage(")
        )
        forbiddenLegacyTokens.forEach { token ->
            assertFalse("Developer tools page body must not return to FinalDeveloperToolsPage: $token", legacy.contains(token))
        }
        assertTrue(
            "Developer tools page body should live in assistant_settings.",
            page.contains("internal data class AssistantDeveloperToolsPageArgs(") &&
                page.contains("internal data class AssistantDeveloperToolsPageState(") &&
                page.contains("internal data class AssistantDeveloperToolsPageCallbacks(") &&
                page.contains("internal fun AssistantDeveloperToolsPage(args: AssistantDeveloperToolsPageArgs)") &&
                page.contains("V88NetworkMode.values().forEach") &&
                page.contains("outboundNumberSubtitle(") &&
                page.contains("callbacks.onChangeMode(DeveloperDataMode.Filled)") &&
                page.contains("callbacks.onResetPermissions")
        )
        assertFalse(page.contains("重置声音克隆引导"))
        assertFalse(page.contains("强制声音克隆引导"))
        assertFalse(page.contains("onResetVoiceCloneGuide"))
        assertFalse(page.contains("onForceVoiceGuideChange"))
        assertFalse(argsBuilder.contains("forceVoiceCloneGuide"))
        assertFalse(argsBuilder.contains("onForceVoiceCloneGuideChange"))
        assertFalse(argsBuilder.contains("onVoiceCloneGuideSkippedChange"))
        assertFalse(argsFactory.contains("forceVoiceCloneGuide"))
        assertFalse(argsFactory.contains("onForceVoiceCloneGuideChange"))
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Developer tools page UI must not depend on runtime/business dependency: $dependency",
                page.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyTokens = listOf(
            "LazyColumn(",
            "PaddingValues(",
            "V88NetworkMode.values().forEach",
            "真实数据状态",
            "固定外呼号码",
            "网络状态模拟",
            "重置所有权限"
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
