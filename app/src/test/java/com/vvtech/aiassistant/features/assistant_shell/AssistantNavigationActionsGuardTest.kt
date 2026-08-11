package com.vvtech.aiassistant.features.assistant_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantNavigationActionsGuardTest {
    @Test
    fun rootDelegatesNavigationReturnPolicyToShellActions() {
        val root = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText()
        val actions = File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantNavigationActions.kt")
            .readText()
        val rootNavigationActions =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootNavigationActions.kt")
                .readText()
        val taskFlowActions =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootTaskFlowActions.kt")
                .readText()
        val actionGraph =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText()
        val primaryShell =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt")
                .readText()
        val assistantFactory =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostAssistantArgsFactory.kt")
                .readText()
        val mainFactory =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostMainArgsFactory.kt")
                .readText()
        val oldHelper = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantMainTabNavigation.kt")
        val openSingleFlowBody = actionGraph
            .substringAfter("onOpenSingleFlowPage = {")
            .substringBefore("onResumeSingleFlowPage =")

        assertFalse(oldHelper.exists())

        assertTrue(root.contains("val rootNavigationActions = rootActionGraph.navigation"))
        assertFalse(root.contains("AssistantRootNavigationActions("))
        assertTrue(actionGraph.contains("AssistantRootNavigationActions("))
        assertTrue(root.contains("onOpenSubPage = rootNavigationActions::openSubPage"))
        assertTrue(root.contains("onBackToMainTab = rootNavigationActions::backToMainTab"))
        assertTrue(root.contains("onSwitchMainTab = rootNavigationActions::switchMainTab"))
        assertTrue(openSingleFlowBody.contains("rootNavigationActions.openSubPage(FinalPage.SingleFlow)"))
        assertTrue(primaryShell.contains("pauseAssistantSingleFlowForSystemBack("))
        assertTrue(root.contains("val rootTaskFlowActions = rootActionGraph.taskFlow"))
        assertFalse(root.contains("AssistantRootTaskFlowActions("))
        assertTrue(actionGraph.contains("AssistantRootTaskFlowActions("))
        assertTrue(root.contains("taskFlow = rootTaskFlowActions"))
        assertTrue(assistantFactory.contains("onStopTask = actions.taskFlow::resetTaskFlow"))
        assertTrue(mainFactory.contains("actions.taskFlow.pauseTaskFlowAndReturnToPreviousTab("))
        assertTrue(mainFactory.contains("actions.taskFlow::returnResultToHome"))

        assertFalse(root.contains("switchFinalMainTab("))
        assertFalse(root.contains("openFinalSubPage("))
        assertFalse(root.contains("val mainTabSwitchCallbacks"))
        assertFalse(root.contains("val subPageOpenCallbacks"))
        assertFalse(root.contains("val returnToMainTabCallbacks"))
        assertFalse(root.contains("fun switchMainTab("))
        assertFalse(root.contains("fun openSubPage("))
        assertFalse(root.contains("fun backToMainTab("))
        assertFalse(root.contains("switchAssistantMainTab("))
        assertFalse(root.contains("backToAssistantMainTab("))
        assertFalse(root.contains("AssistantMainTabSwitchCallbacks("))
        assertFalse(root.contains("AssistantReturnToMainTabCallbacks("))
        assertFalse(root.contains("val targetPage = finalPageForMainTab(targetTab)"))
        assertFalse(root.contains("reason = \"close:"))
        assertFalse(root.contains("reason = \"back:"))
        assertFalse(root.contains("resetAssistantTaskFlow("))
        assertFalse(root.contains("pauseAssistantTaskFlowAndReturnToPreviousTab("))
        assertFalse(root.contains("returnAssistantResultToHome("))

        assertTrue(actions.contains("fun switchAssistantMainTab("))
        assertTrue(actions.contains("fun openAssistantSubPageWithPolicy("))
        assertTrue(actions.contains("fun backToAssistantMainTab("))
        assertTrue(actions.contains("fun resetAssistantTaskFlow("))
        assertTrue(actions.contains("fun pauseAssistantTaskFlowAndReturnToPreviousTab("))
        assertTrue(actions.contains("fun pauseAssistantSingleFlowForSystemBack("))
        assertTrue(actions.contains("fun returnAssistantResultToHome("))
        assertTrue(actions.contains("\"close:"))
        assertTrue(actions.contains("\"back:"))
        assertTrue(rootNavigationActions.contains("class AssistantRootNavigationActions("))
        assertTrue(rootNavigationActions.contains("AssistantMainTabSwitchCallbacks("))
        assertTrue(rootNavigationActions.contains("AssistantSubPageOpenCallbacks("))
        assertTrue(rootNavigationActions.contains("AssistantReturnToMainTabCallbacks("))
        assertTrue(rootNavigationActions.contains("switchAssistantMainTab("))
        assertTrue(rootNavigationActions.contains("openAssistantSubPageWithPolicy("))
        assertTrue(rootNavigationActions.contains("backToAssistantMainTab("))
        assertTrue(rootNavigationActions.contains("AssistantHomeNotificationReadActions.markPendingRead("))
        assertTrue(taskFlowActions.contains("resetAssistantTaskFlow("))
        assertTrue(taskFlowActions.contains("pauseAssistantTaskFlowAndReturnToPreviousTab("))
        assertTrue(taskFlowActions.contains("returnAssistantResultToHome("))
    }
}
