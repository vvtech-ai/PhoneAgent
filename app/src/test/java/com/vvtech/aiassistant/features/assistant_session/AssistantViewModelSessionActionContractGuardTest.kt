package com.vvtech.aiassistant.features.assistant_session

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelSessionActionContractGuardTest {
    @Test
    fun sessionActionContractsDoNotLiveInsideAssistantViewModel() {
        val viewModelFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/AssistantViewModel.kt"
        )
        val contractFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionActionContract.kt"
        )
        val viewModel = viewModelFile.readText(Charsets.UTF_8)
        val contract = contractFile.readText(Charsets.UTF_8)

        assertTrue(contractFile.readLines(Charsets.UTF_8).size <= 300)
        assertFalse(viewModel.contains("internal data class ActionableSummary"))
        assertFalse(viewModel.contains("internal data class PendingSelectionContinuation"))
        assertTrue(viewModel.contains("AssistantSessionActionableSummary"))
        assertTrue(viewModel.contains("AssistantSessionPendingSelectionContinuation"))
        assertTrue(contract.contains("internal data class AssistantSessionActionableSummary"))
        assertTrue(contract.contains("val summary: SummaryData"))
        assertTrue(contract.contains("val callPageSeed: CallPageData"))
        assertTrue(contract.contains("internal data class AssistantSessionPendingSelectionContinuation"))
        assertTrue(contract.contains("val sceneType: String"))
        assertTrue(contract.contains("val targetName: String"))
    }

    @Test
    fun sessionBoundaryDoesNotReferenceViewModelNestedActionContracts() {
        val sourceRoots = listOf(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session",
            "src/main/java/com/vvtech/aiassistant/features/assistant_actions"
        ).map(::sourceFile)
        val combinedSource = sourceRoots
            .flatMap { root -> root.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList() }
            .joinToString("\n") { it.readText(Charsets.UTF_8) }

        assertFalse(combinedSource.contains("AssistantViewModel.ActionableSummary"))
        assertFalse(combinedSource.contains("AssistantViewModel.PendingSelectionContinuation"))
        assertTrue(combinedSource.contains("AssistantSessionActionableSummary("))
        assertTrue(combinedSource.contains("AssistantSessionPendingSelectionContinuation("))
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
