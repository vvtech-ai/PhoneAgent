package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelLocalizedStatusFacadeGuardTest {
    @Test
    fun localizedStatusFacadesLiveOutsideViewModel() {
        val viewModel = File("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt")
            .readText()
        val facade =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_status/AssistantViewModelLocalizedStatusFacade.kt")
                .readText()
        val viewmodelFacade =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_status/AssistantViewModelLocalizedStatusViewmodelFacade.kt")
                .readText()
        val handlerGraph =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_lifecycle/AssistantViewModelHandlerGraph.kt")
                .readText()

        assertTrue(viewModel.contains("internal val localizedStatusTextProvider"))
        assertTrue(handlerGraph.contains("localizedListeningStatus = { viewModel.localizedListeningStatus() }"))
        assertTrue(
            handlerGraph.contains(
                "localizedTapMicToContinueStatus = { viewModel.localizedTapMicToContinueStatus() }"
            )
        )

        assertFalse(viewModel.contains("fun localizedTaskReadyStatus"))
        assertFalse(viewModel.contains("fun localizedListeningStatus"))
        assertFalse(viewModel.contains("fun localizedConfirmingDetailsStatus"))
        assertFalse(viewModel.contains("fun localizedSelectionOptionConfirmFailureStatus"))

        assertTrue(facade.contains("internal fun AssistantViewModel.localizedTaskReadyStatus()"))
        assertTrue(facade.contains("internal fun AssistantViewModel.localizedListeningStatus()"))
        assertTrue(facade.contains("internal fun AssistantViewModel.localizedConfirmingDetailsStatus("))
        assertTrue(facade.contains("sceneType: String? = internalUiState.value.sceneType"))
        assertTrue(facade.contains("localizedStatusTextProvider.confirmingDetailsStatus(sceneType)"))
        assertTrue(viewmodelFacade.contains("package com.vvtech.aiassistant.features.assistant.viewmodel"))
        assertTrue(viewmodelFacade.contains("internal fun AssistantViewModel.localizedConfirmingDetailsStatus("))
    }
}
