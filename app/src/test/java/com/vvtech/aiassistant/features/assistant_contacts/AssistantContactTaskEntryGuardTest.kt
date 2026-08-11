package com.vvtech.aiassistant.features.assistant_contacts

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantContactTaskEntryGuardTest {
    @Test
    fun contactDetailOpensHomeBackedSkillSheetBeforeStartingTask() {
        val detailPage = source(
            "main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactDetailPage.kt"
        )
        val pageHost = source(
            "main/java/com/vvtech/aiassistant/features/assistant/AssistantContactPageHostArgs.kt"
        )
        val skillSheet = source(
            "main/java/com/vvtech/aiassistant/features/assistant_contacts/AssistantContactSkillSheet.kt"
        )
        val contactEntry = source(
            "main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootContactSkillEntry.kt"
        )
        val singleFlowHost = source(
            "main/java/com/vvtech/aiassistant/features/assistant/AssistantSingleFlowPageHost.kt"
        )

        assertTrue(detailPage.contains("label = \"拨打电话\""))
        assertTrue(detailPage.contains("primary = true"))
        assertTrue(detailPage.contains("label = \"发起任务\""))
        assertTrue(detailPage.contains("AssistantContactSkillSheetRoute("))
        assertTrue(pageHost.contains("navigation.onStartContactSkill("))
        assertFalse(pageHost.contains("\"请帮我联系 \$selectedContactName\""))
        assertFalse(pageHost.contains("navigation.onOpenContactSingleFlow("))
        assertTrue(skillSheet.contains("buildAssistantContactSkillOptions(state.cards)"))
        assertTrue(skillSheet.contains("HomeCardEntryDispatcher("))
        assertTrue(skillSheet.contains("AgentInitialSkillLaunchStore::arm"))
        assertTrue(skillSheet.contains("if (!option.enabled) return@AssistantContactSkillSheet"))
        assertTrue(contactEntry.contains("buildAssistantContactSkillOpening("))
        assertTrue(contactEntry.contains("fallbackOpening = AgentInitialSkillLaunchStore.peekOpening()"))
        assertTrue(contactEntry.contains("selectedContact = selectedContact"))
        assertTrue(singleFlowHost.contains("assistantViewModel.armSelectedContactForNextTurn("))
        assertTrue(singleFlowHost.contains("onConsumeSingleFlowSelectedContact()"))
    }

    private fun source(relativePath: String): String =
        File("src/$relativePath").readText(Charsets.UTF_8)
}
