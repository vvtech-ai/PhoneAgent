package com.vvtech.aiassistant.features.assistant_contacts

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantContactMethodsPageBoundaryGuardTest {
    @Test
    fun contactMethodsPagesDelegateUiBodyToContactsBoundary() {
        val legacyFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalContactMethodsPage.kt")
        val listFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactMethodsPage.kt"
        )
        val editFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactMethodEditPage.kt"
        )
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val listComponent = listFile.readText(Charsets.UTF_8)
        val editComponent = editFile.readText(Charsets.UTF_8)

        assertTrue("Legacy contact methods page should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 80)
        assertTrue("Assistant contact methods list component must stay below the new-file guard threshold.", listFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue("Assistant contact method edit component must stay below the new-file guard threshold.", editFile.readLines(Charsets.UTF_8).size < 300)
        assertTrue(legacy.contains("AssistantContactMethodsPage("))
        assertTrue(legacy.contains("AssistantContactMethodEditPage("))

        forbiddenLegacyImplementationTokens.forEach { token ->
            assertFalse("Contact methods UI implementation must not return to legacy file: $token", legacy.contains(token))
        }
        expectedListComponentTokens.forEach { token ->
            assertTrue("Assistant contact methods list component is missing: $token", listComponent.contains(token))
        }
        expectedEditComponentTokens.forEach { token ->
            assertTrue("Assistant contact method edit component is missing: $token", editComponent.contains(token))
        }
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Pure contact methods list component must not depend on runtime/business dependency: $dependency",
                listComponent.contains(dependency)
            )
            assertFalse(
                "Pure contact method edit component must not depend on runtime/business dependency: $dependency",
                editComponent.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenLegacyImplementationTokens = listOf(
            "LazyColumn(",
            "FinalContactMethodCardV3",
            "MutableInteractionSource",
            "Icons.Rounded.DeleteOutline",
            "FinalInputFieldV3(",
            "FinalGenderSelectorV3(",
            "FinalActionButton(",
            "items(entries)",
            "text = \"默认\""
        )

        val expectedListComponentTokens = listOf(
            "internal fun AssistantContactMethodsPage(",
            "private fun AssistantContactMethodsEmptyState(",
            "private fun AssistantContactMethodCard(",
            "private fun AssistantContactMethodRadio(",
            "private fun AssistantContactDefaultBadge(",
            "LazyColumn(",
            "FinalWideButtonV3("
        )

        val expectedEditComponentTokens = listOf(
            "internal data class AssistantContactMethodEditPageState",
            "internal data class AssistantContactMethodEditPageCallbacks",
            "internal data class AssistantContactMethodEditPageArgs",
            "internal fun AssistantContactMethodEditPage(",
            "private fun AssistantContactMethodDeleteButton(",
            "FinalInputFieldV3(",
            "FinalGenderSelectorV3(",
            "FinalActionButton(",
            "Icons.Rounded.DeleteOutline"
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
