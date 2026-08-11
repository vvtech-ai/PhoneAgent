package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantCallsDialSheetBoundaryGuardTest {
    @Test
    fun callsDialSheetImplementationStaysOutOfLegacyAssistantFile() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalCallsPage.kt")
        val componentFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantCallsDialSheet.kt")
        val partsFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantDialerParts.kt")
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val component = componentFile.readText(Charsets.UTF_8)
        val componentText = "$component\n${partsFile.readText(Charsets.UTF_8)}"

        assertTrue("FinalCallsPage should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 80)
        assertTrue("AssistantCallsDialSheet must stay below the new-file guard threshold.", componentFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(
            "Legacy calls page should delegate to the assistant_calls boundary.",
            legacy.contains("import com.vvtech.aiassistant.features.assistant_calls.AssistantCallsDialSheet") &&
                legacy.contains("import com.vvtech.aiassistant.features.assistant_calls.AssistantDialPad") &&
                legacy.contains("fun FinalCallsDialSheetV2(") &&
                legacy.contains("fun FinalDialPadV2(") &&
                legacy.contains("AssistantCallsDialSheet(") &&
                legacy.contains("AssistantDialPad(")
        )
        forbiddenLegacyImplementationTokens.forEach { token ->
            assertFalse("Dial sheet implementation must not return to FinalCallsPage: $token", legacy.contains(token))
        }
        assertTrue(
            "Calls dial sheet implementation should live in the assistant_calls boundary.",
            component.contains("internal fun AssistantCallsDialSheet(") &&
                component.contains("history: List<FinalCallRecord>") &&
                component.contains("selectedCountryIso: String") &&
                component.contains("promptBeforeTranslationDial: Boolean") &&
                component.contains("myLanguage: String") &&
                component.contains("otherLanguage: String")
        )
        callbackTokens.forEach { token ->
            assertTrue("Calls dial sheet must preserve callback wiring: $token", componentText.contains(token))
        }
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Pure calls UI component must not depend on runtime/business dependency: $dependency",
                componentText.contains(dependency)
            )
        }
    }

    @Test
    fun dialerKeepsV62DemoLayoutAndCompactHistoryRows() {
        val sheet = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantCallsDialSheet.kt"
        ).readText(Charsets.UTF_8)
        val parts = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantDialerParts.kt"
        ).readText(Charsets.UTF_8)
        val history = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantDialHistoryList.kt"
        ).readText(Charsets.UTF_8)
        val recentPolicy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/DialRecentCallPolicy.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(parts.contains("fillMaxWidth().height(80.dp)"))
        assertTrue(parts.contains("fontSize = 22.sp"))
        assertTrue(parts.contains("overflow = TextOverflow.Clip"))
        assertTrue(parts.contains(".padding(bottom = 10.dp)"))
        assertTrue(parts.contains("size(64.dp)"))
        assertTrue(parts.contains("Color(0xFF6C5CE7)"))
        assertTrue(parts.contains("Color(0xFF34C759)"))
        assertTrue(parts.contains("horizontalArrangement = Arrangement.SpaceBetween"))
        assertFalse(parts.contains("height(76.dp)"))
        assertTrue(sheet.contains("Modifier.weight(1f).padding(top = 24.dp)"))
        assertTrue(history.contains("DialHistoryTypeTag"))
        assertTrue(history.contains("DialHistoryNumberAndTimeRow"))
        assertTrue(history.contains(".padding(vertical = 8.dp)"))
        assertTrue(history.contains("TextOverflow.Clip"))
        assertTrue(recentPolicy.contains("\"实时翻译\""))
        assertTrue(recentPolicy.contains("else null"))
        assertFalse(recentPolicy.contains("\"普通通话\""))
        assertFalse(history.contains("Icons.Default.CallMade"))
        assertFalse(history.contains("Icons.Default.CallMissed"))
        assertFalse(history.contains("SystemHistoryPermissionCard"))
    }

    @Test
    fun translationPresetCallButtonKeepsV62DemoSizeAndColors() {
        val presets = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/TranslationPresetsSheet.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(presets.contains(".height(54.dp)"))
        assertTrue(presets.contains("RoundedCornerShape(18.dp)"))
        assertTrue(presets.contains("Color(0xFF7C6DFF), Color(0xFF6C5CE7)"))
        assertTrue(presets.contains("Color(0xFF34C759), Color(0xFF28A745)"))
        assertTrue(presets.contains("Brush.verticalGradient(colors)"))
        assertTrue(presets.contains("fontSize = 16.sp"))
    }

    private companion object {
        val forbiddenLegacyImplementationTokens = listOf(
            "private fun FinalDialSheetIconButton",
            "private fun FinalDialCallButton",
            "private fun FinalDialTranslateToggle",
            "val rows = listOf(",
            "Icons.Rounded.Translate",
            "R.drawable.ic_dial_collapse",
            "R.drawable.ic_dial_delete",
            "R.drawable.ic_dial_phone_filled"
        )

        val callbackTokens = listOf(
            "onClick = onClose",
            "AssistantDialPad(",
            "translateEnabled = translateEnabled",
            "onTranslateEnabledChange = locationGate.onTranslationToggleRequested",
            "onCountryClick",
            "onHistorySelect",
            "onDial()"
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
