package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalMainTab
import com.vvtech.aiassistant.features.assistant.FinalPage
import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantMainTabPermissionTest {
    @Test
    fun contactsWithoutPermissionWaitsForPermissionResultBeforeNavigation() {
        val events = mutableListOf<String>()

        switchAssistantMainTab(
            tab = FinalMainTab.Contacts,
            state = AssistantMainTabSwitchState(
                currentMainTab = FinalMainTab.Home,
                currentPage = FinalPage.Home,
                contactsPermissionGranted = false,
                taskStarted = false
            ),
            callbacks = callbacks(events)
        )

        assertEquals(listOf("requestContactsPermission"), events)
    }

    private fun callbacks(events: MutableList<String>) = AssistantMainTabSwitchCallbacks(
        onRequestContactsPermission = { events += "requestContactsPermission" },
        onOpenCallsDialSheet = { events += "openCallsDialSheet" },
        onStartVoiceEntry = { events += "startVoiceEntry" },
        onApplyMainTab = { tab, page -> events += "apply:$tab:$page" },
        onHideCallsDialSheet = { events += "hideCallsDialSheet" },
        onCloseHomeComposer = { events += "closeHomeComposer" },
        onOpenTasksTab = { events += "openTasksTab" }
    )
}
