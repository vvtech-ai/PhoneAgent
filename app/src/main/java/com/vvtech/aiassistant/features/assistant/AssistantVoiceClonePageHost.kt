package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_shell.AssistantSettingsNavigationCallbacks
import com.vvtech.aiassistant.features.assistant_shell.returnToAssistantSettings
import com.vvtech.aiassistant.features.assistant_voice_clone.enrollment.VoiceCloneLifecycleEffect

@Composable
internal fun AssistantVoiceClonePageHost(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    settings: SettingsPageArgs,
    voiceClone: VoiceCloneArgs
) {
    with(navigation) {
        with(settings) {
            with(voiceClone) {
                val settingsNavigationCallbacks = AssistantSettingsNavigationCallbacks(
                    onPageChange = onPageChange,
                    onOpenSubPage = onOpenSubPage
                )
                when (targetPage) {
                    FinalPage.VoiceIdentitySettings -> FinalVoiceIdentityPageV3(
                        status = voiceCloneStatus,
                        loading = voiceCloneLoading,
                        actionLoading = voiceCloneActionLoading,
                        error = voiceCloneError,
                        onBack = { returnToAssistantSettings(settingsNavigationCallbacks) },
                        onSelectAiVoice = onSelectAiVoiceForCalls,
                        onSelectCloneVoice = onSelectCloneVoiceForCalls,
                        onStartClone = {
                            onOpenVoiceCloneFlow(true)
                        }
                    )

                    FinalPage.VoiceCloneSettings -> {
                        VoiceCloneLifecycleEffect(
                            submissionState = voiceCloneSubmissionState,
                            onProcessBackgrounded = onVoiceCloneLifecycleInterrupted,
                            onCompletedProcessForegrounded = { onStartUsingVoiceClone(false) }
                        )
                        FinalVoiceClonePageV3(
                        scripts = voiceCloneScripts,
                        samples = voiceCloneSamples,
                        loading = voiceCloneLoading,
                        uploading = voiceCloneUploading,
                        actionLoading = voiceCloneActionLoading,
                        error = voiceCloneError,
                        recordingScriptId = voiceCloneRecordingScriptId,
                        face = voiceCloneFace,
                        enrollment = voiceCloneEnrollment,
                        submissionState = voiceCloneSubmissionState,
                        currentScriptIndex = voiceCloneCurrentScriptIndex,
                        onBack = { onPageChange(FinalPage.RealtimeCallVoiceSettings) },
                        onRefresh = onRefreshVoiceCloneStatus,
                        onRecord = onVoiceCloneRecord,
                        onStop = onVoiceCloneStop,
                        onSubmitRecording = onSubmitVoiceCloneRecording,
                        onRerecord = onVoiceCloneRerecord,
                        onStartUsing = onStartUsingVoiceClone
                        )
                    }

                    else -> Unit
                }
            }
        }
    }
}
