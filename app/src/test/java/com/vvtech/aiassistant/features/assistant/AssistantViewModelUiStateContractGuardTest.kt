package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantViewModelUiStateContractGuardTest {
    @Test
    fun viewModelDoesNotDefineUiStateContract() {
        val viewModel = source("features/assistant/AssistantViewModel.kt")
        val contract = source("features/assistant_contract/AssistantViewModelUiStateContract.kt")

        assertFalse(viewModel.contains("data class Index9AssistantUiState"))
        assertTrue(contract.contains("data class Index9AssistantUiState"))
        assertTrue(contract.contains("val apiAsrPartialText: String? = null"))
        assertTrue(contract.contains("val locationDisplayText: String = \"\""))
    }

    @Test
    fun viewModelDoesNotDefineTaskVoiceProviderPolicy() {
        val viewModel = source("features/assistant/AssistantViewModel.kt")
        val policy = source("features/assistant_contract/TaskVoiceProviderPolicy.kt")

        assertFalse(viewModel.contains("internal fun isBackendTaskVoiceProvider("))
        assertTrue(policy.contains("internal fun isBackendTaskVoiceProvider("))
        assertTrue(policy.contains("normalized == \"qwen\" || normalized == \"doubao\""))
    }

    private fun source(relativePath: String): String {
        return File("src/main/java/com/vvtech/aiassistant/$relativePath").readText()
    }
}
