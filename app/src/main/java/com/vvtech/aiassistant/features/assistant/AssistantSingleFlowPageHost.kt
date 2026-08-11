package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_pure_voice.ocr.PureVoiceOcrHostCallbacks
import com.vvtech.aiassistant.features.assistant_singleflow.SingleFlowNativeDemoScreenArgs

@Composable
internal fun AssistantSingleFlowPageHost(
    navigation: PageHostNavigationArgs,
    assistant: AssistantPageArgs,
    contact: ContactPageArgs
) {
    with(navigation) {
        with(assistant) {
            with(contact) {
                SingleFlowNativeDemoScreen(
                    SingleFlowNativeDemoScreenArgs(
                        onBack = { onPauseTaskFlowAndReturnToPreviousTab("single_flow_back") },
                        onStop = { onPauseTaskFlowAndReturnToPreviousTab("single_flow_stop") },
                        initialCommand = singleFlowInitialCommand.ifBlank { null },
                        startInVoice = singleFlowStartInVoice,
                        resumeListeningOnly = singleFlowResumeListeningOnly,
                        entryKey = singleFlowEntryKey,
                        onSubmitTask = { task ->
                            assistantViewModel.submitSingleFlowTask(
                                rawText = task,
                                voiceResponse = pureVoiceMode,
                                selectedContact = if (task.isBlank()) {
                                    null
                                } else {
                                    onConsumeSingleFlowSelectedContact()
                                }
                            )
                        },
                        assistantState = assistantUiState,
                        onSelectSelectionOption = { assistantViewModel.onSelectSelectionOption(it) },
                        onConfirmTask = { assistantViewModel.onConfirm() },
                        onSubmitSceneSupplement = { assistantViewModel.submitSceneSupplementTask(it) },
                        onStartVoiceInteraction = { onStartVoiceInteractionWithPermission(false, false) },
                        onStartNewVoiceTaskEntry = if (singleFlowForceNewVoiceEntryStart) {
                            {
                                assistantViewModel.armSelectedContactForNextTurn(
                                    onConsumeSingleFlowSelectedContact()
                                )
                                onStartVoiceInteractionWithPermission(true, false)
                            }
                        } else {
                            null
                        },
                        onToggleVoiceInput = { onStartVoiceInteractionWithPermission(false, true) },
                        onPauseTtsPlayback = { assistantViewModel.stopTtsPlaybackForOptionSelection() },
                        onSpeakVoicePrompt = { assistantViewModel.speakVoicePrompt(it) },
                        onBeginVoiceContactReentry = {},
                        onBeginVoiceDefaultContactConfirmation = {},
                        onBeginVoiceDetailSupplementPrompt = {},
                        onBeginVoiceSummaryConfirmation = {},
                        onVoiceContactCaptured = { onPersistTaskContactIfNeeded(it) },
                        savedContacts = contactMethods.toList(),
                        onCompleteDetailSupplement = { taskContact, detailText ->
                            val normalizedContact = onPersistTaskContactIfNeeded(taskContact)
                            assistantViewModel.completeDetailSupplement(normalizedContact, detailText)
                        },
                        pureVoiceMode = pureVoiceMode,
                        pureVoicePrecheck = pureVoicePrecheck,
                        pureVoiceOcrHostCallbacks = if (pureVoiceMode) {
                            PureVoiceOcrHostCallbacks(
                                onContextChanged = assistantViewModel::updatePureVoiceOcrContext,
                                ensureSessionId = assistantViewModel::ensureAgentSession,
                                pendingInitialOpening = assistantViewModel::pendingInitialOpeningForSession,
                                commitAttachment = assistantViewModel::commitPureVoiceOcrAttachment,
                                loadHistoryImage = assistantViewModel::loadPureVoiceOcrHistoryImage,
                            )
                        } else null,
                        voiceLanguage = voiceLanguage,
                        activeCallModelTitle = activeCallModelTitle,
                        onOpenCallModelSheet = onOpenCallModelSheet,
                        onStopVoiceInteraction = {
                            assistantViewModel.onManualAsrRelease()
                        },
                        onManualPressVoiceInteraction = { assistantViewModel.onManualAsrPress() },
                        onManualCancelVoiceInteraction = { assistantViewModel.onManualAsrCancel() },
                        onManualTooShortVoiceInteraction = { assistantViewModel.onManualAsrTooShort() },
                        onNewTask = onRestartSingleFlow,
                        onGoHome = onGoHomePreservingSession
                    )
                )
            }
        }
    }
}
