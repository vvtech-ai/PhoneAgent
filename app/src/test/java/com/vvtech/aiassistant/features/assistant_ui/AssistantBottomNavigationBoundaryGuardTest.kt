package com.vvtech.aiassistant.features.assistant_ui

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantBottomNavigationBoundaryGuardTest {
    @Test
    fun bottomNavigationImplementationStaysOutOfLegacyAssistantFile() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalBottomNav.kt")
        val barFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantBottomNavigationBar.kt")
        val partsFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_ui/AssistantBottomNavigationParts.kt")
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val bar = barFile.readText(Charsets.UTF_8)
        val parts = partsFile.readText(Charsets.UTF_8)
        val componentText = "$bar\n$parts"

        assertTrue("FinalBottomNav should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 80)
        assertTrue("AssistantBottomNavigationBar must stay below the new-file guard threshold.", barFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue("AssistantBottomNavigationParts must stay below the new-file guard threshold.", partsFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy bottom navigation should delegate to the assistant_ui component boundary.",
            legacy.contains("import com.vvtech.aiassistant.features.assistant_ui.AssistantBottomNavigationBar") &&
                legacy.contains("fun FinalBottomTabBarCompat(") &&
                legacy.contains("fun FinalBottomTabBar(") &&
                legacy.contains("AssistantBottomNavigationBar(")
        )
        forbiddenLegacyImplementationTokens.forEach { token ->
            assertFalse("Bottom navigation implementation must not return to FinalBottomNav: $token", legacy.contains(token))
        }
        assertTrue(
            "Bottom navigation implementation should live in the assistant_ui component boundary.",
            bar.contains("internal fun AssistantBottomNavigationBar(") &&
                parts.contains("internal fun BoxScope.CenterActionButton(") &&
                parts.contains("internal fun BottomNavigationItem(")
        )
        assertTrue("V62 bottom bar must expose a dedicated dial callback.", bar.contains("onDialClick: () -> Unit"))
        assertTrue("Settings must be a visible outer tab.", bar.contains("FinalMainTab.Settings"))
        assertFalse(
            "Calls must no longer be rendered as an outer tab.",
            bar.contains("BottomNavigationItemSpec(FinalMainTab.Calls")
        )
        assertTrue("The center action must always be dial mode.", bar.contains("centerDialMode = true"))
        assertTrue("The center action must open the dialer.", bar.contains("onClick = onDialClick"))
        assertTrue(
            "Bottom navigation background should keep the V63 prototype translucent color.",
            bar.contains("Color(0xADF8F8FA)")
        )
        assertFalse(
            "Bottom navigation must not regress to the opaque mask color.",
            bar.contains("Color(0xF2F8F8FA)")
        )
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Pure UI bottom navigation must not depend on runtime/business dependency: $dependency",
                componentText.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyImplementationTokens = listOf(
            "FinalBottomTabBarRound1",
            "FinalNavItemRound1",
            "FinalNavItemV2Unused",
            "R.drawable.ic_final_tab",
            "rememberInfiniteTransition",
            "妫",
            "閼",
            "闁",
            "娴"
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
