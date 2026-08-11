package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneEnrollmentRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

internal class VoiceCloneIdentityReplacementGate(
    private val scope: CoroutineScope,
    private val repository: VoiceCloneEnrollmentRepository,
    private val stateProvider: () -> VoiceCloneEnrollmentState,
    private val verifiedNameLoader: suspend () -> String?,
    private val generationProvider: () -> Long,
    private val dispatch: (VoiceCloneEnrollmentEvent) -> Unit
) {
    private var checkJob: Job? = null

    fun prepare(realName: String, certNo: String, onReady: () -> Unit) {
        if (checkJob?.isActive == true) return
        dispatch(VoiceCloneEnrollmentEvent.ReplacementCheckRequested)
        val generation = generationProvider()
        checkJob = scope.launch {
            runCatching {
                requiresIdentityNameReplacement(verifiedNameLoader(), realName) ||
                    repository.checkReplacement(certNo)
            }.onSuccess { replacementRequired ->
                if (generation != generationProvider()) return@onSuccess
                if (replacementRequired) {
                    dispatch(VoiceCloneEnrollmentEvent.ReplacementConfirmationRequired)
                } else {
                    dispatch(VoiceCloneEnrollmentEvent.ReplacementNotRequired)
                    onReady()
                }
            }.onFailure { throwable ->
                if (generation == generationProvider()) {
                    dispatch(
                        VoiceCloneEnrollmentEvent.InputRejected(
                            throwable.message ?: "身份信息核验失败，请重试。"
                        )
                    )
                }
            }
        }
    }

    fun confirm(onReady: () -> Unit) {
        val state = stateProvider()
        if (!state.replacementConfirmationRequired || state.busy) return
        dispatch(VoiceCloneEnrollmentEvent.ReplacementConfirmed)
        onReady()
    }

    fun dismiss() {
        dispatch(VoiceCloneEnrollmentEvent.ReplacementConfirmationDismissed)
    }

    fun cancel() {
        checkJob?.cancel()
        checkJob = null
    }
}
