package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRootPermissionRuntimeShellTest {
    @Test
    fun rootPermissionRuntimeOwnsPermissionWiring() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val runtimeFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPermissionRuntimeShell.kt"
        )
        val runtime = runtimeFile.readText(Charsets.UTF_8)

        assertTrue(root.contains("rememberAssistantRootPermissionRuntime("))
        assertTrue(root.contains("AssistantRootPermissionRuntimeDeps("))
        assertTrue(root.contains("AssistantRootPermissionRuntimeCallbacks("))
        assertTrue(root.contains("val rootActivityLaunchers = permissionRuntime.rootActivityLaunchers"))
        assertTrue(root.contains("val voicePermissionLaunchers = permissionRuntime.voicePermissionLaunchers"))
        assertTrue(root.contains("val contactPermissionLaunchers = permissionRuntime.contactPermissionLaunchers"))

        listOf(
            "AssistantRootActivityLauncherCallbackFactoryDeps(",
            "AssistantRootVoicePermissionLauncherCallbackDeps(",
            "rememberAssistantVoicePermissionLaunchers(",
            "AssistantRootContactPermissionRuntimeDeps(",
            "val contactPermissionRuntime = rememberAssistantRootContactPermissionRuntime("
        ).forEach { token ->
            assertFalse("permission wiring should not live in Root: $token", root.contains(token))
        }

        listOf(
            "buildAssistantRootActivityLauncherCallbacks(",
            "rememberAssistantRootActivityLaunchers(rootActivityLauncherCallbacks)",
            "buildAssistantRootVoicePermissionLauncherCallbacks(",
            "rememberAssistantVoicePermissionLaunchers(",
            "rememberAssistantRootContactPermissionRuntime(",
            "AssistantRootContactPermissionRuntimeDeps(",
            "isAssistantAgentPermissionGranted(deps.context, request)",
            "onClearPendingVoiceEntryState = callbacks.onClearPendingVoiceEntryState",
            "rootActivityLaunchers = rootActivityLaunchers",
            "voicePermissionLaunchers = voicePermissionLaunchers",
            "contactPermissionLaunchers = contactPermissionRuntime.launchers"
        ).forEach { token ->
            assertTrue("permission runtime shell should own: $token", runtime.contains(token))
        }
        assertTrue(runtimeFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(root.lines().size < 1000)
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
