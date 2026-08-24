package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.features.assistant_settings.AssistantRealtimeCallVoiceSettingsPage
import com.vvtech.aiassistant.features.assistant_settings.AssistantRealtimeCallVoiceSettingsPageCallbacks
import com.vvtech.aiassistant.features.assistant_settings.AssistantRealtimeCallVoiceSettingsPageState
import com.vvtech.aiassistant.features.assistant_settings.AssistantIdentityProfileStatus
import com.vvtech.aiassistant.features.assistant_shell.AssistantSettingsNavigationCallbacks
import com.vvtech.aiassistant.features.assistant_shell.AssistantTaskPageNavigationCallbacks
import com.vvtech.aiassistant.features.assistant_shell.AssistantTaskPageNavigationState
import com.vvtech.aiassistant.features.assistant_shell.followUpAssistantTask
import com.vvtech.aiassistant.features.assistant_shell.openAssistantContactMethods
import com.vvtech.aiassistant.features.assistant_shell.openAssistantDeveloperTools
import com.vvtech.aiassistant.features.assistant_shell.openAssistantMyIdentity
import com.vvtech.aiassistant.features.assistant_shell.openAssistantRealtimeCallVoiceSettings
import com.vvtech.aiassistant.features.assistant_shell.openAssistantRealtimeProviderSettings
import com.vvtech.aiassistant.features.assistant_shell.openAssistantSettings
import com.vvtech.aiassistant.features.assistant_shell.openAssistantTaskConversation
import com.vvtech.aiassistant.features.assistant_shell.openAssistantTaskResult
import com.vvtech.aiassistant.features.assistant_shell.openAssistantOriginalAudioSettings
import com.vvtech.aiassistant.features.assistant_shell.openAssistantTranslationProviderSettings
import com.vvtech.aiassistant.features.assistant_shell.openAssistantVoiceIdentitySettings
import com.vvtech.aiassistant.features.assistant_shell.resumeCurrentAssistantTaskConversation
import com.vvtech.aiassistant.features.assistant_shell.returnToAssistantSettings
import com.vvtech.aiassistant.features.translation_call.model.TranslationCallSettingsPolicy
import com.vvtech.aiassistant.features.translation_call.state.TranslationCallSettingsStateHolder
import com.vvtech.aiassistant.features.translation_call.ui.screen.OriginalAudioSettingsHost
import com.vvtech.aiassistant.features.translation_call.ui.screen.RegionAwareSipAccountSettingsHost
import com.vvtech.aiassistant.features.translation_call.ui.screen.RegionAwareTranslationProviderSettingsHost

@Composable
internal fun AssistantTaskSettingsPageHost(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    assistant: AssistantPageArgs,
    contact: ContactPageArgs,
    task: TaskPageArgs,
    settings: SettingsPageArgs,
    providerSettings: ProviderSettingsArgs,
    voiceClone: VoiceCloneArgs
) {
    val context = LocalContext.current.applicationContext
    val translationSettingsHolder = remember(context) {
        TranslationCallSettingsStateHolder.from(context)
    }
    val translationRegion by translationSettingsHolder.region.collectAsState()
    val translationSettings by translationSettingsHolder.settings.collectAsState()
    val translationVisibility = TranslationCallSettingsPolicy.visibility(translationRegion)

    with(navigation) {
        with(assistant) {
            with(contact) {
                LaunchedEffect(targetPage) {
                    if (targetPage == FinalPage.Settings) {
                        onRefreshUserIdentity()
                    }
                }
                with(task) {
                    with(settings) {
                        with(providerSettings) {
                            with(voiceClone) {
                                val taskNavigationState = AssistantTaskPageNavigationState(
                                    activeSessionId = assistantViewModel.agentSessionId,
                                    hasLocalConversationSteps = assistantUiState.clarificationSteps.isNotEmpty(),
                                    useSingleFlowConversation = UseSingleFlowConversationInFinal
                                )
                                val taskNavigationCallbacks = AssistantTaskPageNavigationCallbacks(
                                    onResumeConversation = assistantViewModel::resumeConversation,
                                    onResumeSingleFlow = onResumeSingleFlow,
                                    onOpenSingleFlow = onOpenSingleFlow,
                                    onOpenSubPage = onOpenSubPage
                                )
                                val settingsNavigationCallbacks = AssistantSettingsNavigationCallbacks(
                                    onPageChange = onPageChange,
                                    onOpenSubPage = onOpenSubPage
                                )
                                when (targetPage) {
                                    FinalPage.Tasks -> FinalTasksPageV3(
                                        records = visibleTaskRecords,
                                        loading = isFinalTaskPageLoading(
                                            realTaskLoading = realTaskLoading,
                                            conversationLoading = conversationLoading
                                        ),
                                        error = realTaskError ?: conversationError,
                                        activeConversationTitle = if (shouldShowActiveConversationShortcut(
                                                sessionId = assistantViewModel.agentSessionId,
                                                taskStatus = assistantUiState.taskStatus
                                            )
                                        ) {
                                            assistantUiState.clarificationSteps
                                                .firstOrNull { it.role == VoiceRole.User }
                                                ?.text?.take(40)
                                            ?: "进行中的对话"
                                        } else null,
                                        conversations = conversations,
                                        onResumeConversation = {
                                            resumeCurrentAssistantTaskConversation(
                                                state = taskNavigationState,
                                                callbacks = taskNavigationCallbacks
                                            )
                                        },
                                        onNewConversation = onOpenSingleFlowDefault,
                                        onOpenConversation = { sessionId ->
                                            openAssistantTaskConversation(sessionId, taskNavigationCallbacks)
                                        },
                                        onRefresh = {
                                            onRefreshRealTasks()
                                            assistantViewModel.loadConversations()
                                        },
                                        onOpenResult = { openAssistantTaskResult(taskNavigationCallbacks) },
                                        onFollowup = {
                                            followUpAssistantTask(taskNavigationState, taskNavigationCallbacks)
                                        }
                                    )

                                    FinalPage.Settings -> FinalSettingsPageV3(
                                        developerToolsVisible = developerModeEnabled,
                                        onOpenDeveloperTools = {
                                            openAssistantDeveloperTools(settingsNavigationCallbacks)
                                        },
                                        onOpenContactMethods = {
                                            onSelectedMethodReset()
                                            openAssistantContactMethods(settingsNavigationCallbacks)
                                        },
                                        appLanguage = appLanguage,
                                        onAppLanguageChange = onAppLanguageChange,
                                        onOpenMyIdentity = {
                                            onUserIdentityErrorChange(null)
                                            onRefreshUserIdentity()
                                            openAssistantMyIdentity(settingsNavigationCallbacks)
                                        },
                                        myIdentityStatus = AssistantIdentityProfileStatus.fromServer(
                                            userIdentityPayload?.verificationStatus
                                        ),
                                        contactMethodCount = contactMethods.size,
                                        realtimeProviderSummary = activeRealtimeProviderSummary,
                                        realtimeProviderLoading = realtimeProviderLoading,
                                        realtimeProviderError = realtimeProviderError,
                                        onOpenRealtimeProvider = {
                                            onRefreshRealtimeProvider(true)
                                            openAssistantRealtimeProviderSettings(settingsNavigationCallbacks)
                                        },
                                        translationProviderSummary = activeTranslationProviderSummary,
                                        translationProviderLoading = translationProviderLoading,
                                        translationProviderError = translationProviderError,
                                        onOpenTranslationProvider = {
                                            openAssistantOriginalAudioSettings(settingsNavigationCallbacks)
                                        },
                                        voiceCloneStatus = voiceCloneStatus,
                                        voiceCloneLoading = voiceCloneLoading,
                                        voiceCloneError = voiceCloneError,
                                        onOpenVoiceClone = {
                                            onRefreshVoiceCloneStatus()
                                            openAssistantVoiceIdentitySettings(settingsNavigationCallbacks)
                                        },
                                        realtimeCallVoiceSummary = activeRealtimeCallVoiceSummary,
                                        realtimeCallVoiceLoading = realtimeCallVoiceLoading,
                                        realtimeCallVoiceError = realtimeCallVoiceError,
                                        onOpenRealtimeCallVoice = {
                                            onRefreshRealtimeCallVoice(true)
                                            openAssistantRealtimeCallVoiceSettings(settingsNavigationCallbacks)
                                        },
                                        selectedVoiceModelTitle = selectedVoiceModelTitle,
                                        onOpenVoiceModel = {
                                            onRefreshRealtimeProvider(true)
                                            onShowVoiceModelSheetChange(true)
                                        },
                                        onOpenTrustedCallee = onOpenTrustedCalleeAuthorization,
                                        versionUpdateSummary = "v${BuildConfig.VERSION_NAME}",
                                        versionUpdateChecking = otaUpdateChecking,
                                        onCheckVersionUpdate = onCheckVersionUpdate,
                                        logUploadInProgress = logUploadInProgress,
                                        onUploadLogs = onUploadLogs,
                                        onLogout = { onShowLogoutConfirmChange(true) }
                                    )

                                    FinalPage.RealtimeProviderSettings -> FinalRealtimeProviderPageV3(
                                        providerResponse = realtimeProviderResponse,
                                        loading = realtimeProviderLoading,
                                        switching = realtimeProviderSwitching,
                                        error = realtimeProviderError,
                                        appLanguage = appLanguage,
                                        onBack = { returnToAssistantSettings(settingsNavigationCallbacks) },
                                        onRefresh = { onRefreshRealtimeProvider(true) },
                                        onSelectProvider = onSwitchRealtimeCallProvider,
                                        onOpenVoiceSettings = {
                                            onRefreshRealtimeCallVoice(true)
                                            onRefreshVoiceCloneStatus()
                                            openAssistantRealtimeCallVoiceSettings(settingsNavigationCallbacks)
                                        }
                                    )

                                    FinalPage.RealtimeCallVoiceSettings -> AssistantRealtimeCallVoiceSettingsPage(
                                        state = AssistantRealtimeCallVoiceSettingsPageState(
                                            response = realtimeCallVoiceResponse,
                                            loading = realtimeCallVoiceLoading,
                                            switching = realtimeCallVoiceSwitching,
                                            error = realtimeCallVoiceError,
                                            activeProvider = realtimeProviderResponse?.activeProvider ?: "QWEN_OMNI_PLUS",
                                            cloneStatus = voiceCloneStatus,
                                            cloneLoading = voiceCloneLoading,
                                            cloneActionLoading = voiceCloneActionLoading,
                                            cloneError = voiceCloneError
                                        ),
                                        callbacks = AssistantRealtimeCallVoiceSettingsPageCallbacks(
                                            onBack = { openAssistantRealtimeProviderSettings(settingsNavigationCallbacks) },
                                            onSelectVoice = { voice ->
                                                onSwitchRealtimeCallVoice(voice, "AI")
                                            },
                                            onSelectCloneVoice = {
                                                onSwitchRealtimeCallVoice(null, "CLONE")
                                            },
                                            onStartClone = {
                                                onOpenVoiceCloneFlow(true)
                                            }
                                        ),
                                        appLanguage = appLanguage
                                    )

                                    FinalPage.SipAccountSettings -> RegionAwareSipAccountSettingsHost(
                                        settings = settings,
                                        navigation = settingsNavigationCallbacks,
                                        region = translationRegion,
                                        visibility = translationVisibility
                                    )

                                    FinalPage.TranslationProviderSettings ->
                                        RegionAwareTranslationProviderSettingsHost(
                                            providers = providerSettings,
                                            navigation = settingsNavigationCallbacks,
                                            holder = translationSettingsHolder,
                                            region = translationRegion,
                                            visibility = translationVisibility,
                                            regionalSettings = translationSettings
                                        )

                                    FinalPage.OriginalAudioSettings -> OriginalAudioSettingsHost(
                                        navigation = settingsNavigationCallbacks,
                                        holder = translationSettingsHolder,
                                        settings = translationSettings
                                    )

                                    else -> Unit
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
