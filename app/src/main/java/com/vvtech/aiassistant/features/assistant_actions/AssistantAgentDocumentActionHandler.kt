package com.vvtech.aiassistant.features.assistant_actions

import com.vvtech.aiassistant.features.assistant.*

import android.net.Uri
import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class AssistantAgentDocumentActionHandler(
    private val viewModel: AssistantViewModel
) {
    private val documentImportUseCase = AssistantAgentDocumentImportUseCase(
        context = viewModel.appContext,
        repository = viewModel.repository
    )

    fun onDocumentPickerCancelled() {
        viewModel.agentStreamHandler.onAgentDocumentSubmit(
            documentImportUseCase.cancelledResult()
        )
    }

    fun onDocumentPicked(uri: Uri) {
        val request = viewModel.internalUiState.value.agentDocumentRequest ?: return
        viewModel.internalUiState.update {
            it.copy(
                agentDocumentImporting = true,
                processingTurn = true,
                error = null,
                status = currentAppText("正在解析文件", "Parsing file")
            )
        }
        viewModel.viewModelScope.launch {
            val result = documentImportUseCase.parse(uri, request.maxBytes)
            viewModel.agentStreamHandler.onAgentDocumentSubmit(result)
        }
    }
}
