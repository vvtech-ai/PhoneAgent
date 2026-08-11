package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.features.assistant.EffectiveTaskContact
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class DetailSupplementActionHandler(
    private val viewModel: AssistantViewModel
) {

    fun completeDetailSupplement(
        contact: EffectiveTaskContact,
        detailSummaryText: String
    ) {
        with(viewModel) {
            val detailSceneType = internalUiState.value.detailSupplement?.sceneType ?: internalUiState.value.sceneType
            val normalizedDetail = detailSummaryText.trim()
            val taskId = internalUiState.value.detailSupplement?.taskId ?: internalUiState.value.taskId
            val pendingActionable = pendingDetailActionable
            if (taskId.isNullOrBlank()) {
                return
            }

            val syncPayload = buildList {
                buildReservationContactSyncSentence(detailSceneType, contact).takeIf { it.isNotBlank() }
                    ?.let(::add)
                buildDetailSupplementSyncSentence(normalizedDetail).takeIf { it.isNotBlank() }
                    ?.let(::add)
            }.joinToString("\n")
            AppFileLogger.i(
                "Index9AssistantVM",
                "completeDetailSupplement taskId=$taskId detailLength=${normalizedDetail.length} payload=$syncPayload"
            )

            internalUiState.update {
                it.copy(
                    processingTurn = true,
                    listening = false,
                    error = null,
                    status = submittingStatus(
                        language = currentVoiceLanguage(),
                        hasDetail = normalizedDetail.isNotBlank()
                    ),
                    detailSupplement = it.detailSupplement?.copy(loading = true)
                )
            }

            viewModelScope.launch {
                val response = if (syncPayload.isBlank()) {
                    null
                } else {
                    runCatching {
                        sendDetailSupplementPayload(syncPayload, taskId)
                    }.getOrElse { throwable ->
                        internalUiState.update {
                            it.copy(
                                processingTurn = false,
                                status = throwable.message ?: failureStatus(currentVoiceLanguage()),
                                error = throwable.message ?: failureError(currentVoiceLanguage()),
                                detailSupplement = it.detailSupplement?.copy(loading = false)
                            )
                        }
                        return@launch
                    }
                }

                val responseTaskId = response?.session?.taskId ?: taskId
                detailSupplementCompletedTaskId = responseTaskId
                detailSupplementContactTaskId = responseTaskId
                detailSupplementContactValue = buildLocalizedContactSummaryValue(
                    language = currentVoiceLanguage(),
                    sceneType = detailSceneType,
                    contact = contact
                )
                detailSupplementInfoTaskId = responseTaskId
                detailSupplementInfoValue = normalizedDetail.ifBlank { null }
                pendingDetailActionable = null

                if (pendingActionable != null) {
                    internalUiState.update {
                        it.copy(
                            detailSupplement = null,
                            summary = decorateSummaryWithSupplement(
                                responseTaskId,
                                pendingActionable.summary
                            ),
                            confirmLabel = pendingActionable.confirmLabel,
                            processingTurn = false,
                            loading = false,
                            error = null,
                            status = localizedTaskReadyStatus()
                        )
                    }
                    primarySummaryAction = pendingActionable.primaryAction
                    latestCallPageSeed = pendingActionable.callPageSeed
                    refreshHistory()
                } else if (response == null) {
                    internalUiState.update {
                        it.copy(
                            detailSupplement = null,
                            processingTurn = false,
                            loading = false,
                            error = null,
                            status = localizedTaskReadyStatus()
                        )
                    }
                } else {
                    internalUiState.update { it.copy(detailSupplement = null) }
                    applyChannelSession(response)
                    refreshHistory()
                }
            }
        }
    }

    private fun submittingStatus(language: VoiceLanguage, hasDetail: Boolean): String {
        return if (hasDetail) {
            when (language) {
                VoiceLanguage.English -> "Organizing extra details..."
                VoiceLanguage.Japanese -> "追加条件を整理しています..."
                VoiceLanguage.Chinese -> "正在整理补充细节..."
            }
        } else {
            when (language) {
                VoiceLanguage.English -> "Confirming booking information..."
                VoiceLanguage.Japanese -> "予約情報を確認しています..."
                VoiceLanguage.Chinese -> "正在确认预订信息..."
            }
        }
    }

    private fun failureStatus(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Failed to add extra details. Please try again later."
        VoiceLanguage.Japanese -> "追加条件の保存に失敗しました。あとでもう一度お試しください。"
        VoiceLanguage.Chinese -> "补充细节失败，请稍后再试"
    }

    private fun failureError(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Failed to add extra details"
        VoiceLanguage.Japanese -> "追加条件の保存に失敗しました"
        VoiceLanguage.Chinese -> "补充细节失败"
    }

    private fun buildLocalizedContactSummaryValue(
        language: VoiceLanguage,
        sceneType: String,
        contact: EffectiveTaskContact
    ): String {
        if (language == VoiceLanguage.Chinese) {
            return buildContactSummaryValue(sceneType, contact)
        }
        val name = contact.name.trim().ifBlank { contact.displayName() }
            .removeSuffix("先生")
            .removeSuffix("女士")
        val phone = contact.phone.trim()
        return when (language) {
            VoiceLanguage.English -> {
                if (sceneType == "FLIGHT_BOOKING" && contact.idCardNumber.isNotBlank()) {
                    "$name, ID ${contact.idCardNumber}, $phone"
                } else {
                    "$name, $phone"
                }
            }

            VoiceLanguage.Japanese -> {
                if (sceneType == "FLIGHT_BOOKING" && contact.idCardNumber.isNotBlank()) {
                    "$name、身分証番号 ${contact.idCardNumber}、電話番号 $phone"
                } else {
                    "$name、電話番号 $phone"
                }
            }

            VoiceLanguage.Chinese -> buildContactSummaryValue(sceneType, contact)
        }
    }
}
