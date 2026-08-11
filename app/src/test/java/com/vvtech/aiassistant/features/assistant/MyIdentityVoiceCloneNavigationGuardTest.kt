package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MyIdentityVoiceCloneNavigationGuardTest {
    @Test
    fun identityUsesDirectVoiceModelSettingsEntryWithoutConfirmationDialog() {
        val screen = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/MyIdentityScreen.kt"
        ).readText(Charsets.UTF_8)
        val factory = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(screen.contains("label = \"声音克隆\""))
        assertTrue(screen.contains("声音克隆用于使用我的声音进行 AI 通话"))
        assertTrue(screen.contains("placeholder = \"让AI知道该如何介绍自己\""))
        assertFalse(screen.contains("showAuthenticationConfirm"))
        assertFalse(screen.contains("MyIdentityAuthenticationDialog("))
        assertTrue(factory.contains("runtime.provider.refreshRealtimeCallProvider(force = true)"))
        assertTrue(factory.contains("callbacks.onOpenSubPage(FinalPage.RealtimeProviderSettings)"))
        assertFalse(factory.contains("runtime.voiceClone.openFlow()"))
    }

    private fun sourceFile(path: String): File = listOf(File(path), File("android/app/$path"))
        .first { it.exists() }
}
