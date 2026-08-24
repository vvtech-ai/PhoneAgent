package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.SystemClock
import androidx.compose.runtime.MutableState
import com.vvtech.aiassistant.data.local.voiceclone.VoiceCloneVerificationEnvironment
import com.vvtech.aiassistant.data.local.voiceclone.VoiceCloneVerificationEnvironmentProvider
import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneEnrollmentRepository
import com.vvtech.aiassistant.data.remote.voiceclone.VoiceCloneVerificationClientObservationRequest
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.model.VoiceCloneStatusResponse
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class VoiceCloneEnrollmentCoordinator(
    private val context: Context,
    private val scope: CoroutineScope,
    private val repository: VoiceCloneEnrollmentRepository,
    private val sdk: IdProSdkAdapter,
    private val environmentProvider: VoiceCloneVerificationEnvironmentProvider,
    private val stateHolder: MutableState<VoiceCloneEnrollmentState>,
    private val identityPrefillLoader: suspend () -> VoiceCloneIdentityPrefill?,
    private val onIdentityVerified: () -> Unit,
    private val onCloneAccepted: (VoiceCloneStatusResponse) -> Unit
) {
    private var verificationJob: Job? = null
    private var preparationJob: Deferred<Result<String>>? = null
    private var identityPrefillJob: Job? = null
    private var verifiedIdentityName: String? = null
    private var sessionGeneration: Long = 0
    private var sdkStartedAtMs: Long = 0L
    private val runtimeLogger = VoiceCloneEnrollmentLogger()
    private val replacementGate = VoiceCloneIdentityReplacementGate(
        scope = scope,
        repository = repository,
        stateProvider = { state },
        verifiedNameLoader = {
            val prefill = identityPrefillLoader()
            prefill?.name?.trim()
                ?.takeIf { prefill.verified && it.isNotEmpty() }
                .also { verifiedIdentityName = it }
        },
        generationProvider = { sessionGeneration },
        dispatch = ::dispatch
    )

    val state: VoiceCloneEnrollmentState
        get() = stateHolder.value

    fun setAgreement(accepted: Boolean) {
        dispatch(
            VoiceCloneEnrollmentEvent.AgreementChanged(accepted)
        )
        if (accepted) startPreparation("agreement")
        else clearPreparation()
    }

    fun continueAfterConsent() {
        val before = state.step
        dispatch(VoiceCloneEnrollmentEvent.ContinueAfterConsent)
        if (before != VoiceCloneEnrollmentStep.CONSENT
            || state.step != VoiceCloneEnrollmentStep.IDENTITY) {
            return
        }
        startPreparation("consent_continue")
        loadIdentityName()
    }

    fun updateIdentity(realName: String, idCardNumber: String) = dispatch(
        VoiceCloneEnrollmentEvent.IdentityChanged(realName, idCardNumber)
    )

    fun beginIdentityEdit(field: VoiceCloneIdentityFieldKind) {
        dispatch(VoiceCloneEnrollmentEvent.IdentityEditStarted(field))
    }

    fun prepareVerification(onReady: () -> Unit) {
        val snapshot = state
        if (!snapshot.canStartVerification()) {
            return
        }
        val validationError = validateIdentity(snapshot)
        if (validationError != null) {
            dispatch(VoiceCloneEnrollmentEvent.InputRejected(validationError))
            return
        }
        replacementGate.prepare(snapshot.realName, snapshot.idCardNumber, onReady)
    }

    fun confirmReplacement(onReady: () -> Unit) {
        replacementGate.confirm(onReady)
    }

    fun dismissReplacement() {
        replacementGate.dismiss()
    }

    fun activateCompletedClone(
        improvementConsent: Boolean,
        onResult: (Result<VoiceCloneStatusResponse>) -> Unit
    ) {
        val snapshot = state
        val attemptId = snapshot.attemptId
        if (snapshot.step != VoiceCloneEnrollmentStep.VERIFIED || attemptId.isNullOrBlank()) {
            runtimeLogger.activationBlocked(snapshot.step)
            onResult(Result.failure(
                IllegalStateException(currentAppText(
                    "本次声音克隆记录已失效，请重新开始。",
                    "This voice cloning record has expired. Please start again."
                ))
            ))
            return
        }
        scope.launch {
            runtimeLogger.activationStarted(attemptId)
            val result = runCatching {
                repository.activateCompletedClone(attemptId, improvementConsent)
            }
            runtimeLogger.activationFinished(attemptId, result)
            onResult(result)
        }
    }

    fun startVerification() {
        val snapshot = state
        if (!snapshot.canStartVerification() || verificationJob?.isActive == true) {
            runtimeLogger.verificationBlocked(
                if (snapshot.busy || verificationJob?.isActive == true) {
                    "already_running"
                } else {
                    "invalid_step"
                }
            )
            return
        }
        val validationError = validateIdentity(snapshot)
        if (validationError != null) {
            runtimeLogger.verificationBlocked("invalid_input")
            dispatch(VoiceCloneEnrollmentEvent.InputRejected(validationError))
            return
        }
        val activity = context.findActivity()
        if (activity == null) {
            runtimeLogger.verificationBlocked("activity_unavailable")
            dispatch(VoiceCloneEnrollmentEvent.Failed(currentAppText(
                "当前页面无法启动实名认证，请重新进入。",
                "This page cannot start identity verification. Please reopen it."
            )))
            return
        }
        val generation = ++sessionGeneration
        runtimeLogger.verificationStarted(snapshot.step)
        dispatch(VoiceCloneEnrollmentEvent.VerificationRequested)
        verificationJob = scope.launch {
            runCatching {
                val metaInfo = preparedMetaInfo()
                repository.initialize(
                    consentVersion = CONSENT_VERSION,
                    realName = snapshot.realName,
                    certNo = snapshot.idCardNumber,
                    metaInfo = metaInfo,
                    replacementConfirmed = snapshot.replacementConfirmed
                )
            }.onSuccess { initialized ->
                if (generation != sessionGeneration) return@onSuccess
                val scriptText = runCatching {
                    requireVoiceCloneVerificationScript(initialized.scriptText)
                }.getOrElse {
                    fail(it)
                    return@onSuccess
                }
                runtimeLogger.verificationInitialized(
                    initialized.attemptId,
                    initialized.scriptVersion,
                    initialized.scriptTemplateId
                )
                dispatch(
                    VoiceCloneEnrollmentEvent.VerificationInitialized(
                        initialized.attemptId,
                        initialized.certifyId,
                        scriptText,
                        initialized.scriptVersion,
                        initialized.scriptTemplateId
                    )
                )
                sdkStartedAtMs = SystemClock.elapsedRealtime()
                sdk.verify(activity, initialized.certifyId) { result ->
                    scope.launch {
                        if (generation == sessionGeneration) handleSdkResult(result, generation)
                    }
                }.onFailure { throwable -> fail(throwable) }
            }.onFailure { throwable -> fail(throwable) }
        }
    }

    fun reset(message: String? = null) {
        val snapshot = state
        runtimeLogger.reset(snapshot, !message.isNullOrBlank())
        sessionGeneration++
        verificationJob?.cancel()
        verificationJob = null
        replacementGate.cancel()
        clearPreparation()
        identityPrefillJob?.cancel()
        identityPrefillJob = null
        sdk.abortActiveVerification()
        dispatch(
            message?.takeIf { it.isNotBlank() }
                ?.let(VoiceCloneEnrollmentEvent::Failed)
                ?: VoiceCloneEnrollmentEvent.Exit
        )
    }

    private suspend fun handleSdkResult(result: IdProSdkResult, generation: Long) {
        if (generation != sessionGeneration) return
        val snapshot = state
        val attemptId = snapshot.attemptId
        val diagnosis = AliyunIdProSdkResultClassifier.classify(result)
        val environment = runCatching { environmentProvider.snapshot() }.getOrElse {
            VoiceCloneVerificationEnvironment("unknown", "NONE", false)
        }
        val sdkElapsedMs = (SystemClock.elapsedRealtime() - sdkStartedAtMs)
            .coerceIn(0L, MAX_SDK_ELAPSED_MS)
        val requiresServerQuery = VoiceCloneSdkResultPolicy.requiresServerQuery(diagnosis.code)
        runtimeLogger.sdkFinished(
            diagnosis = diagnosis,
            completed = requiresServerQuery,
            attemptId = attemptId,
            scriptVersion = snapshot.scriptVersion,
            scriptTemplateId = snapshot.scriptTemplateId,
            environment = environment,
            sdkElapsedMs = sdkElapsedMs
        )
        dispatch(VoiceCloneEnrollmentEvent.SdkFinished(diagnosis))
        if (!requiresServerQuery) {
            if (!attemptId.isNullOrBlank()) {
                reportClientObservation(attemptId, diagnosis, environment, sdkElapsedMs)
            }
            return
        }
        val queryAttemptId = attemptId ?: return fail(IllegalStateException(currentAppText(
            "认证流水已失效",
            "The verification session has expired."
        )))
        repeat(MAX_STATUS_POLLS) {
            if (generation != sessionGeneration) return
            val status = runCatching { repository.status(queryAttemptId) }
                .getOrElse {
                    reportClientObservation(queryAttemptId, diagnosis, environment, sdkElapsedMs)
                    return fail(it)
                }
            if (generation != sessionGeneration) return
            runtimeLogger.providerStatusChanged(
                queryAttemptId,
                status.status,
                status.providerSubCode,
                snapshot.scriptVersion,
                snapshot.scriptTemplateId
            )
            dispatch(
                VoiceCloneEnrollmentEvent.ServerStatus(
                    status.status,
                    status.providerSubCode
                )
            )
            if (state.step == VoiceCloneEnrollmentStep.CLONING) {
                onIdentityVerified()
                completeClone(queryAttemptId, generation)
                reportClientObservation(queryAttemptId, diagnosis, environment, sdkElapsedMs)
                return
            }
            if (!shouldContinueVoiceCloneStatusPolling(state.step)) {
                runtimeLogger.statusPollingStopped(queryAttemptId, state.step)
                reportClientObservation(queryAttemptId, diagnosis, environment, sdkElapsedMs)
                return
            }
            delay(STATUS_POLL_INTERVAL_MS)
        }
        reportClientObservation(queryAttemptId, diagnosis, environment, sdkElapsedMs)
        fail(IllegalStateException(currentAppText(
            "认证结果查询超时，请重新开始。",
            "Verification result lookup timed out. Please start again."
        )))
    }

    private fun reportClientObservation(
        attemptId: String,
        diagnosis: VoiceCloneSdkDiagnosis,
        environment: VoiceCloneVerificationEnvironment,
        sdkElapsedMs: Long
    ) {
        scope.launch {
            val result = runCatching {
                repository.reportClientObservation(
                    attemptId,
                    VoiceCloneVerificationClientObservationRequest(
                        deviceModel = environment.deviceModel,
                        networkType = environment.networkType,
                        networkValidated = environment.networkValidated,
                        sdkCode = diagnosis.code,
                        sdkSubCode = diagnosis.subCode,
                        reasonCategory = diagnosis.reasonCategory.name,
                        sdkElapsedMs = sdkElapsedMs
                    )
                )
            }
            runtimeLogger.clientObservationFinished(attemptId, result)
        }
    }

    private fun validateIdentity(state: VoiceCloneEnrollmentState): String? = when {
        state.step != VoiceCloneEnrollmentStep.IDENTITY -> currentAppText(
            "请先阅读并同意授权说明。",
            "Read and agree to the authorization notice first."
        )
        state.realName.trim().length !in 2..32 -> currentAppText(
            "请输入正确的真实姓名。",
            "Enter a valid legal name."
        )
        !ChinaIdCardValidator.isValid(state.idCardNumber) -> currentAppText(
            "请输入正确的身份证号码。",
            "Enter a valid ID number."
        )
        else -> null
    }

    private suspend fun completeClone(attemptId: String, generation: Long) {
        runtimeLogger.completionStarted(attemptId)
        val response = runCatching {
            repository.complete(attemptId)
        }.getOrElse {
            runtimeLogger.completionFailed(attemptId, it)
            if (generation == sessionGeneration) {
                val message = VoiceCloneCompletionFailureMessagePolicy.messageFor(it)
                fail(IllegalStateException(message, it))
            }
            return
        }
        if (generation != sessionGeneration) return
        runtimeLogger.completionAccepted(attemptId, response.status)
        dispatch(VoiceCloneEnrollmentEvent.CloneAccepted(response.status))
        if (state.step == VoiceCloneEnrollmentStep.VERIFIED) {
            onCloneAccepted(response)
        }
    }

    private fun fail(throwable: Throwable) {
        val snapshot = state
        runtimeLogger.failed(snapshot, throwable)
        dispatch(
            VoiceCloneEnrollmentEvent.Failed(
                throwable.message?.takeIf { it.isNotBlank() } ?: currentAppText(
                    "实名认证失败，请重新开始。",
                    "Identity verification failed. Please start again."
                )
            )
        )
    }

    private fun dispatch(event: VoiceCloneEnrollmentEvent) {
        val before = stateHolder.value
        val after = VoiceCloneEnrollmentReducer.reduce(before, event)
        stateHolder.value = after
        runtimeLogger.stepChanged(before, after, event.javaClass.simpleName)
    }

    private fun startPreparation(source: String) {
        if (preparationJob != null) return
        runtimeLogger.preparationStarted()
        preparationJob = scope.async(Dispatchers.Default) {
            sdk.prepare(context).also {
                runtimeLogger.preparationFinished(it, source)
            }
        }
    }

    private fun clearPreparation() {
        preparationJob?.cancel()
        preparationJob = null
        sdk.clearPreparedSession()
    }

    private fun loadIdentityName() {
        identityPrefillJob?.cancel()
        val generation = sessionGeneration
        identityPrefillJob = scope.launch {
            val prefill = runCatching { identityPrefillLoader() }.getOrNull()
            val name = prefill?.name?.trim().orEmpty()
            verifiedIdentityName = name.takeIf { prefill?.verified == true && it.isNotEmpty() }
            if (generation != sessionGeneration
                || state.step != VoiceCloneEnrollmentStep.IDENTITY
                || state.realName.isNotBlank()) {
                return@launch
            }
            runtimeLogger.identityPrefillFinished(name.isNotBlank())
            if (name.isNotBlank()) {
                dispatch(VoiceCloneEnrollmentEvent.IdentityChanged(name, state.idCardNumber))
            }
        }
    }

    private suspend fun preparedMetaInfo(): String {
        val prepared = preparationJob?.await()
        if (prepared?.isSuccess == true) {
            runtimeLogger.preparationReused()
            return prepared.getOrThrow()
        }
        runtimeLogger.preparationStarted()
        return withContext(Dispatchers.Default) {
            sdk.prepare(context)
        }.also {
            runtimeLogger.preparationFinished(it, "start_fallback")
        }.getOrThrow()
    }

    private fun Context.findActivity(): Activity? {
        var current: Context? = this
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return current as? Activity
    }

    private companion object {
        const val CONSENT_VERSION = "voice-clone-enrollment-v2"
        const val MAX_STATUS_POLLS = 60
        const val STATUS_POLL_INTERVAL_MS = 1_000L
        const val MAX_SDK_ELAPSED_MS = 3_600_000L
    }
}
