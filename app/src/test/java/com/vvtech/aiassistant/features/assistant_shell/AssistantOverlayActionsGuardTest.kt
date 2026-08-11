package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantOverlayActionsGuardTest {
    @Test
    fun rootDelegatesOverlayPermissionAndModelActionsToShellActions() {
        val root = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText()
        val factory = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootOverlayArgsFactory.kt"
        ).readText()
        val hostShell = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
        ).readText()
        val permissionActions = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantOverlayPermissionActions.kt"
        ).readText()
        val modelActions = File(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantOverlayModelActions.kt"
        ).readText()

        assertTrue(root.contains("buildAssistantRootHostArgs("))
        assertFalse(root.contains("buildAssistantRootOverlayArgs("))
        assertTrue(hostShell.contains("buildAssistantRootOverlayArgs("))
        assertFalse(root.contains("handleOverlayNetworkRetry("))
        assertFalse(root.contains("handleOverlayPermissionAllow("))
        assertFalse(root.contains("handleOverlayPermissionDeny("))
        assertFalse(root.contains("handleOverlayVoiceModelSelection("))

        assertFalse(root.contains("AssistantOverlayHost@"))
        assertFalse(root.contains("when (permission)"))
        assertFalse(root.contains("return@AssistantOverlayHost"))
        assertFalse(root.contains("val provider = modelId.toRealtimeCallProviderValue()"))
        assertFalse(root.contains("option?.enabled == false"))
        assertFalse(root.contains("providerRuntime.realtimeProviderSwitching ->"))

        assertTrue(permissionActions.contains("fun handleOverlayNetworkRetry("))
        assertTrue(permissionActions.contains("fun handleOverlayPermissionAllow("))
        assertTrue(permissionActions.contains("fun handleOverlayPermissionDeny("))
        assertTrue(permissionActions.contains("when (permission)"))

        assertTrue(modelActions.contains("fun handleOverlayVoiceModelSelection("))
        assertTrue(modelActions.contains("toRealtimeCallProviderValue()"))
        assertTrue(modelActions.contains("option?.enabled == false"))

        assertTrue(factory.contains("handleOverlayNetworkRetry("))
        assertTrue(factory.contains("handleOverlayPermissionAllow("))
        assertTrue(factory.contains("handleOverlayPermissionDeny("))
        assertTrue(factory.contains("handleOverlayVoiceModelSelection("))
    }
}
