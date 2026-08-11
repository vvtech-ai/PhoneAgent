package com.vvtech.aiassistant.features.assistant_actions

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantUserDecisionActionHandlerGuardTest {
    @Test
    fun viewModelDelegatesUserDecisionActionsToHandler() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()
        val facade = File("src/main/java/com/vvtech/aiassistant/features/assistant_facade/AssistantViewModelTaskSessionFacades.kt")
            .readText()
        val handler = File("src/main/java/com/vvtech/aiassistant/features/assistant_actions/AssistantUserDecisionActionHandler.kt")
            .readText()

        assertFalse(viewModel.contains("fun onSelectSelectionOption(option: SelectionSheetOption)"))
        assertTrue(
            "onSelectSelectionOption must remain a thin delegate.",
            Regex(
                """fun\s+AssistantViewModel\.onSelectSelectionOption\(option:\s*SelectionSheetOption\)\s*=\s*""" +
                    """\s*userDecisionActionHandler\.onSelectSelectionOption\(option\)"""
            ).containsMatchIn(facade)
        )
        assertTrue(
            "onConfirm must remain a thin delegate.",
            Regex("""fun\s+AssistantViewModel\.onConfirm\(\)\s*=\s*userDecisionActionHandler\.onConfirm\(\)""")
                .containsMatchIn(facade)
        )
        assertTrue(handler.contains("class AssistantUserDecisionActionHandler"))
        assertTrue(handler.contains("sendActionThroughActiveChannel"))
        assertTrue(handler.contains("pendingSelectionContinuation"))
    }
}
