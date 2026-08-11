package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.DeveloperDataMode
import com.vvtech.aiassistant.features.assistant.FinalPage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantDeveloperDataModeActionsTest {
    @Test
    fun filledModeAppliesSettingsClearsRecordsRefreshesTasksThenUpdatesContacts() {
        val recorder = Recorder()

        applyAssistantDeveloperDataMode(
            mode = DeveloperDataMode.Filled,
            state = AssistantDeveloperDataModeActionState(
                activeAccountId = "account-1",
                contactsPermissionGranted = true,
                currentPage = FinalPage.ContactDetail
            ),
            callbacks = recorder.callbacks()
        )

        assertEquals(
            listOf(
                "settings:Filled",
                "clear:account-1",
                "refreshTasks",
                "contacts:Filled:true:ContactDetail"
            ),
            recorder.events
        )
    }

    @Test
    fun emptyModeDoesNotRefreshTasksButStillUpdatesContacts() {
        val recorder = Recorder()

        applyAssistantDeveloperDataMode(
            mode = DeveloperDataMode.Empty,
            state = AssistantDeveloperDataModeActionState(
                activeAccountId = "account-2",
                contactsPermissionGranted = false,
                currentPage = FinalPage.ContactMethods
            ),
            callbacks = recorder.callbacks()
        )

        assertEquals(
            listOf(
                "settings:Empty",
                "clear:account-2",
                "contacts:Empty:false:ContactMethods"
            ),
            recorder.events
        )
    }

    @Test
    fun rootDelegatesDeveloperDataModeActionToShell() {
        val root = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
            .readText(Charsets.UTF_8)
        val action =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantDeveloperDataModeActions.kt")
                .readText(Charsets.UTF_8)
        val rootTaskFlowAction =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootTaskFlowActions.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootActionGraph.kt")
                .readText(Charsets.UTF_8)
        val pageHostSecondaryFactory =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPageHostSecondaryArgsFactory.kt"
            ).readText(Charsets.UTF_8)
        val hostShell =
            sourceFile(
                "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootHostArgsShell.kt"
            ).readText(Charsets.UTF_8)

        assertFalse(root.contains("taskFlowActions = rootTaskFlowActions"))
        assertTrue(hostShell.contains("taskFlowActions = actions.taskFlow"))
        assertFalse(root.contains("onApplyDeveloperDataMode = rootSettingsState::applyDeveloperDataMode"))
        assertTrue(actionGraph.contains("onApplyDeveloperDataMode = state.rootSettings::applyDeveloperDataMode"))
        assertFalse(root.contains("val developerDataModeActionCallbacks = AssistantDeveloperDataModeActionCallbacks("))
        assertFalse(root.contains("applyAssistantDeveloperDataMode("))
        assertFalse(root.contains("when (mode)"))
        assertFalse(root.contains("DeveloperDataMode.Filled ->"))
        assertFalse(root.contains("DeveloperDataMode.Empty ->"))

        assertTrue(action.contains("if (mode == DeveloperDataMode.Filled)"))
        assertTrue(action.contains("onApplyContactDeveloperDataMode"))
        assertTrue(rootTaskFlowAction.contains("AssistantDeveloperDataModeActionCallbacks("))
        assertTrue(rootTaskFlowAction.contains("applyAssistantDeveloperDataMode("))
        assertTrue(pageHostSecondaryFactory.contains("onApplyDeveloperDataMode = state.taskFlowActions::applyDeveloperDataMode"))
    }

    private class Recorder {
        val events = mutableListOf<String>()

        fun callbacks(): AssistantDeveloperDataModeActionCallbacks {
            return AssistantDeveloperDataModeActionCallbacks(
                onApplyDeveloperDataMode = { events += "settings:${it.name}" },
                onClearCallRecordsForAccount = { events += "clear:$it" },
                onRefreshTasks = { events += "refreshTasks" },
                onApplyContactDeveloperDataMode = { mode, contactsGranted, page ->
                    events += "contacts:${mode.name}:$contactsGranted:${page.name}"
                }
            )
        }
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
