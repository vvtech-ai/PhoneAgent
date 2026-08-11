package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import android.os.SystemClock
import com.vvtech.aiassistant.data.local.voiceclone.VoiceCloneVerificationEnvironment
import com.vvtech.aiassistant.data.repository.voiceclone.voiceCloneCompletionHttpStatus
import com.vvtech.aiassistant.data.repository.voiceclone.voiceCloneCompletionStage
import com.vvtech.aiassistant.features.assistant_voice_clone.logVoiceCloneRuntime

internal class VoiceCloneEnrollmentLogger {
    private var flowStartedAtMs = 0L
    private var activationStartedAtMs = 0L
    private var preparationStartedAtMs = 0L
    private var lastProviderStatus: String? = null

    fun verificationBlocked(reason: String) {
        logVoiceCloneRuntime("VOICE_CLONE_VERIFICATION_BLOCKED", "blocked", reason)
    }

    fun verificationStarted(step: VoiceCloneEnrollmentStep) {
        flowStartedAtMs = SystemClock.elapsedRealtime()
        lastProviderStatus = null
        logVoiceCloneRuntime(
            "VOICE_CLONE_VERIFICATION_STARTED",
            provider = PROVIDER,
            stateBefore = step.name
        )
    }

    fun preparationStarted() {
        preparationStartedAtMs = SystemClock.elapsedRealtime()
        logVoiceCloneRuntime(
            "VOICE_CLONE_SDK_PREPARE_STARTED",
            provider = PROVIDER
        )
    }

    fun preparationFinished(result: Result<*>, source: String) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_SDK_PREPARE_FINISHED",
            result = if (result.isSuccess) "success" else "failed",
            reason = if (result.isSuccess) null else "sdk_prepare_failed",
            throwable = result.exceptionOrNull(),
            provider = PROVIDER,
            elapsedMs = elapsedSince(preparationStartedAtMs),
            attributes = mapOf("source" to source)
        )
    }

    fun preparationReused() {
        logVoiceCloneRuntime(
            "VOICE_CLONE_SDK_PREPARE_REUSED",
            result = "success",
            provider = PROVIDER
        )
    }

    fun identityPrefillFinished(success: Boolean) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_IDENTITY_PREFILL_FINISHED",
            result = if (success) "success" else "empty",
            reason = if (success) null else "name_unavailable"
        )
    }

    fun verificationInitialized(
        attemptId: String,
        scriptVersion: String?,
        scriptTemplateId: String?
    ) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_VERIFICATION_INITIALIZED",
            "success",
            attemptId = attemptId,
            provider = PROVIDER,
            stateAfter = VoiceCloneEnrollmentStep.VERIFYING.name,
            elapsedMs = elapsedSinceFlowStart(),
            attributes = scriptAttributes(scriptVersion, scriptTemplateId)
        )
    }

    fun activationBlocked(step: VoiceCloneEnrollmentStep) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_ACTIVATION_BLOCKED",
            "blocked",
            "attempt_unavailable",
            stateBefore = step.name
        )
    }

    fun activationStarted(attemptId: String) {
        activationStartedAtMs = SystemClock.elapsedRealtime()
        logVoiceCloneRuntime(
            "VOICE_CLONE_ACTIVATION_STARTED",
            attemptId = attemptId,
            provider = PROVIDER
        )
    }

    fun activationFinished(attemptId: String, result: Result<*>) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_ACTIVATION_FINISHED",
            result = if (result.isSuccess) "success" else "failed",
            throwable = result.exceptionOrNull(),
            attemptId = attemptId,
            provider = PROVIDER,
            elapsedMs = elapsedSince(activationStartedAtMs)
        )
    }

    fun reset(snapshot: VoiceCloneEnrollmentState, interrupted: Boolean) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_ENROLLMENT_RESET",
            "cancelled",
            if (interrupted) "interrupted" else "exit",
            attemptId = snapshot.attemptId,
            collectionId = snapshot.collection?.collectionId,
            provider = PROVIDER,
            stateBefore = snapshot.step.name,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    fun sdkFinished(
        diagnosis: VoiceCloneSdkDiagnosis,
        completed: Boolean,
        attemptId: String?,
        scriptVersion: String?,
        scriptTemplateId: String?,
        environment: VoiceCloneVerificationEnvironment,
        sdkElapsedMs: Long
    ) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_SDK_FINISHED",
            result = when {
                completed -> "completed"
                diagnosis.reasonCategory == VoiceCloneSdkReasonCategory.USER_CANCELLED -> "cancelled"
                else -> "failed"
            },
            reason = diagnosis.reasonCategory.name.lowercase(),
            attemptId = attemptId,
            provider = PROVIDER,
            elapsedMs = sdkElapsedMs,
            attributes = scriptAttributes(scriptVersion, scriptTemplateId) + mapOf(
                "sdkCode" to diagnosis.code.toString(),
                "sdkSubCode" to diagnosis.subCode,
                "sdkReasonCategory" to diagnosis.reasonCategory.name,
                "deviceModel" to environment.deviceModel,
                "networkType" to environment.networkType,
                "networkValidated" to environment.networkValidated.toString()
            )
        )
    }

    fun clientObservationFinished(attemptId: String, result: Result<Unit>) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_CLIENT_OBSERVATION_FINISHED",
            result = if (result.isSuccess) "success" else "failed",
            reason = if (result.isSuccess) null else "observation_request_failed",
            throwable = result.exceptionOrNull(),
            attemptId = attemptId,
            provider = PROVIDER
        )
    }

    fun providerStatusChanged(
        attemptId: String,
        status: String,
        providerSubCode: String?,
        scriptVersion: String?,
        scriptTemplateId: String?
    ) {
        if (status == lastProviderStatus) return
        logVoiceCloneRuntime(
            "VOICE_CLONE_VERIFICATION_STATUS_CHANGED",
            "success",
            statusValue = status,
            attributes = scriptAttributes(scriptVersion, scriptTemplateId) +
                mapOf("providerSubCode" to providerSubCode),
            attemptId = attemptId,
            provider = PROVIDER,
            stateBefore = lastProviderStatus,
            stateAfter = status,
            elapsedMs = elapsedSinceFlowStart()
        )
        lastProviderStatus = status
    }

    fun statusPollingStopped(
        attemptId: String,
        step: VoiceCloneEnrollmentStep
    ) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_VERIFICATION_POLLING_STOPPED",
            result = "completed",
            reason = "terminal_status",
            attemptId = attemptId,
            provider = PROVIDER,
            stateAfter = step.name,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    fun completionStarted(attemptId: String) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_MFVC_COMPLETION_STARTED",
            attemptId = attemptId,
            provider = PROVIDER,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    fun completionFailed(attemptId: String, throwable: Throwable) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_MFVC_COMPLETION_FAILED",
            "failed",
            throwable = throwable,
            attributes = mapOf(
                "httpStatus" to throwable.voiceCloneCompletionHttpStatus()?.toString(),
                "failureStage" to throwable.voiceCloneCompletionStage()?.name
            ),
            attemptId = attemptId,
            provider = PROVIDER,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    fun completionAccepted(attemptId: String, status: String) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_MFVC_COMPLETION_ACCEPTED",
            "success",
            statusValue = status,
            attemptId = attemptId,
            provider = PROVIDER,
            stateAfter = status,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    fun failed(snapshot: VoiceCloneEnrollmentState, throwable: Throwable) {
        logVoiceCloneRuntime(
            "VOICE_CLONE_ENROLLMENT_FAILED",
            "failed",
            throwable = throwable,
            attemptId = snapshot.attemptId,
            collectionId = snapshot.collection?.collectionId,
            provider = PROVIDER,
            stateBefore = snapshot.step.name,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    fun stepChanged(
        before: VoiceCloneEnrollmentState,
        after: VoiceCloneEnrollmentState,
        triggerEvent: String
    ) {
        if (before.step == after.step) return
        logVoiceCloneRuntime(
            "VOICE_CLONE_STEP_CHANGED",
            "success",
            attributes = mapOf("triggerEvent" to triggerEvent),
            attemptId = after.attemptId ?: before.attemptId,
            collectionId = after.collection?.collectionId ?: before.collection?.collectionId,
            provider = PROVIDER,
            stateBefore = before.step.name,
            stateAfter = after.step.name,
            elapsedMs = elapsedSinceFlowStart()
        )
    }

    private fun elapsedSinceFlowStart(): Long? = elapsedSince(flowStartedAtMs)

    private fun elapsedSince(startedAtMs: Long): Long? =
        startedAtMs.takeIf { it > 0L }?.let { SystemClock.elapsedRealtime() - it }

    private fun scriptAttributes(
        scriptVersion: String?,
        scriptTemplateId: String?
    ): Map<String, String?> = mapOf(
        "scriptVersion" to scriptVersion,
        "scriptTemplateId" to scriptTemplateId
    )

    private companion object {
        const val PROVIDER = "aliyun_mfvc"
    }
}
