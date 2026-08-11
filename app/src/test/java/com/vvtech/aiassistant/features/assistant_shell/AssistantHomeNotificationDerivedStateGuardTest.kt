package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeNotificationDerivedStateGuardTest {
    @Test
    fun rootDelegatesHomeNotificationDerivedStateToShellPolicy() {
        val root = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText()
        val policy = File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantHomeNotificationDerivedState.kt")
            .readText()
        val runtime = File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantHomeNotificationRuntimeShell.kt")
            .readText()
        val assistantFactory =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText()
        val mainFactory =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt")
                .readText()
        val hostShell =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt")
                .readText()

        assertTrue(root.contains("rememberAssistantHomeNotificationRuntimeState("))
        assertTrue(root.contains("AssistantHomeNotificationRuntimeInput("))
        assertTrue(root.contains("homeNotification = homeNotificationDerivedState"))
        assertTrue(assistantFactory.contains("homeNotificationExtra = state.homeNotification.homeNotificationExtra"))
        assertTrue(mainFactory.contains("visibleCallRecords = state.homeNotification.visibleCallRecords"))
        assertFalse(root.contains("homeNotificationDerivedState.taskBadgeCount"))
        assertTrue(hostShell.contains("taskBadgeCount = state.homeNotification.taskBadgeCount"))
        assertFalse(root.contains("deriveAssistantHomeNotificationState("))
        assertFalse(root.contains("AssistantHomeNotificationDerivedStateInput("))
        assertFalse(root.contains("FinalHomeNotificationReadEffect("))
        assertFalse(root.contains("FinalHomeNotificationReadEffectArgs("))

        assertFalse(root.contains("val backendRecords = assistantUiState.historyRecords"))
        assertFalse(root.contains("val completedConversations = remember"))
        assertFalse(root.contains("buildHomeNotificationItems("))
        assertFalse(root.contains("pendingHomeNotificationItems("))
        assertFalse(root.contains("taskBadgeCountFromPendingNotifications("))

        assertTrue(policy.contains("class AssistantHomeNotificationDerivedStateInput"))
        assertTrue(policy.contains("class AssistantHomeNotificationDerivedState"))
        assertTrue(policy.contains("fun deriveAssistantHomeNotificationState"))
        assertTrue(policy.contains("buildHomeNotificationItems("))
        assertTrue(policy.contains("pendingHomeNotificationItems("))
        assertTrue(policy.contains("taskBadgeCountFromPendingNotifications("))

        assertTrue(runtime.contains("class AssistantHomeNotificationRuntimeInput"))
        assertTrue(runtime.contains("fun rememberAssistantHomeNotificationRuntimeState"))
        assertTrue(runtime.contains("deriveAssistantHomeNotificationState("))
        assertTrue(runtime.contains("AssistantHomeNotificationDerivedStateInput("))
        assertTrue(runtime.contains("FinalHomeNotificationReadEffect("))
        assertTrue(runtime.contains("AssistantHomeNotificationReadActions.markPendingRead("))
    }
}
