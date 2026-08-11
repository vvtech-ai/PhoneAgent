package com.vvtech.aiassistant.callengine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.model.ClientSipLeaseResponse
import com.vvtech.aiassistant.repository.AppContainer
import kotlinx.coroutines.runBlocking
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class AndroidAssistantCallEngineGateway(
    context: Context
) : AssistantCallEngineGateway {
    private val appContext = context.applicationContext
    private val taskRepository = AppContainer.taskRepository
    private val executor = Executors.newSingleThreadExecutor()
    private val controlExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val released = AtomicBoolean(false)
    private val hangupRequested = AtomicBoolean(false)
    private val desiredMuted = AtomicBoolean(false)
    private val muteLock = Any()
    @Volatile private var session: AndroidAssistantSipCallSession? = null

    override fun start(
        request: AssistantCallRequest,
        onEvent: (AssistantCallEngineEvent) -> Unit
    ) {
        if (released.get()) {
            onEvent(AssistantCallEngineEvent.Failure("通话资源已释放"))
            return
        }
        session?.hangup()
        hangupRequested.set(false)
        desiredMuted.set(false)
        executor.execute {
            val leaseTraceId = AndroidAssistantSipCallSession.newSessionId()
            var retriesUsed = 0
            while (!released.get() && !hangupRequested.get()) {
                val attempt = retriesUsed + 1
                var lease: ClientSipLeaseResponse? = null
                var next: AndroidAssistantSipCallSession? = null
                var retryFailure: AssistantCallEngineEvent.Failure? = null
                var connected = false
                var ringing = false
                var attemptStartedAtMillis = 0L
                try {
                    val acquiredLease = acquireClientSipLease(request, leaseTraceId)
                    lease = acquiredLease
                    logLeaseAcquired(request, acquiredLease, leaseTraceId, attempt)
                    if (released.get() || hangupRequested.get()) {
                        postEndedIfHangup(onEvent)
                        return@execute
                    }
                    next = AndroidAssistantSipCallSession(
                        context = appContext,
                        request = request,
                        account = acquiredLease.toAssistantSipAccount(),
                        onEvent = { event ->
                            if (
                                event is AssistantCallEngineEvent.PhaseChanged &&
                                event.phase in ConnectedPhases
                            ) {
                                connected = true
                            }
                            if (
                                event is AssistantCallEngineEvent.PhaseChanged &&
                                event.phase == AssistantCallPhase.RINGING
                            ) {
                                ringing = true
                            }
                            if (
                                event is AssistantCallEngineEvent.Failure &&
                                AssistantSipInviteRetryPolicy.shouldRetry(
                                    failure = event,
                                    retriesUsed = retriesUsed,
                                    connected = connected,
                                    ringing = ringing,
                                    elapsedSinceAttemptStartMillis =
                                        System.currentTimeMillis() - attemptStartedAtMillis
                                ) &&
                                !released.get() &&
                                !hangupRequested.get()
                            ) {
                                retryFailure = event
                            } else {
                                if (event is AssistantCallEngineEvent.Failure) {
                                    logTerminalFailure(
                                        traceId = leaseTraceId,
                                        attempt = attempt,
                                        accountTail = acquiredLease.username.takeLast(4),
                                        failure = event
                                    )
                                }
                                mainHandler.post { onEvent(event) }
                            }
                        }
                    )
                    synchronized(muteLock) {
                        session = next
                        next.setMuted(desiredMuted.get())
                    }
                    attemptStartedAtMillis = System.currentTimeMillis()
                    next.run()
                } catch (error: Exception) {
                    logCallFailure(leaseTraceId, attempt, error)
                    mainHandler.post {
                        onEvent(
                            AssistantCallEngineEvent.Failure(
                                error.message ?: "SIP账号获取失败"
                            )
                        )
                    }
                    return@execute
                } finally {
                    if (session === next) session = null
                    releaseClientSipLease(lease, leaseTraceId, attempt)
                }
                val failure = retryFailure ?: return@execute
                if (released.get() || hangupRequested.get()) {
                    postEndedIfHangup(onEvent)
                    return@execute
                }
                retriesUsed += 1
                logInviteRetry(
                    traceId = leaseTraceId,
                    failedAttempt = attempt,
                    accountTail = lease?.username?.takeLast(4).orEmpty(),
                    statusCode = failure.sipStatusCode,
                    elapsedMs = System.currentTimeMillis() - attemptStartedAtMillis,
                    ringing = ringing
                )
            }
        }
    }

    override fun setMuted(muted: Boolean) {
        val activeSession = synchronized(muteLock) {
            desiredMuted.set(muted)
            session
        }
        AppFileLogger.i(
            FileLogTag,
            "event=mute_requested muted=$muted sessionPresent=${activeSession != null}"
        )
        activeSession?.setMuted(muted)
    }

    override fun setSpeakerEnabled(enabled: Boolean) {
        session?.setSpeakerEnabled(enabled)
    }

    override fun sendDtmf(digit: Char) {
        controlExecutor.execute { session?.sendDtmf(digit) }
    }

    override fun hangup() {
        hangupRequested.set(true)
        session?.hangup()
    }

    override fun release() {
        released.set(true)
        desiredMuted.set(false)
        session?.hangup()
        session = null
        executor.shutdown()
        controlExecutor.shutdownNow()
    }

    private fun acquireClientSipLease(
        request: AssistantCallRequest,
        leaseTraceId: String
    ): ClientSipLeaseResponse {
        return runBlocking {
            taskRepository.acquireClientSipLease(
                route = leaseRoute(request),
                purpose = leasePurpose(request),
                callId = leaseTraceId,
                deviceId = deviceId()
            )
        }
    }

    private fun releaseClientSipLease(
        lease: ClientSipLeaseResponse?,
        leaseTraceId: String,
        attempt: Int
    ) {
        if (lease == null) return
        runCatching {
            runBlocking {
                taskRepository.releaseClientSipLease(
                    leaseId = lease.leaseId,
                    reason = "call_session_finished",
                    callId = leaseTraceId,
                    deviceId = deviceId()
                )
            }
        }.onSuccess {
            Log.i(
                Tag,
                "CLIENT_SIP_LEASE_RELEASED leaseTail=${lease.leaseId.takeLast(8)} " +
                    "accountTail=${lease.username.takeLast(4)}"
            )
            AppFileLogger.i(
                FileLogTag,
                "event=lease_released traceId=$leaseTraceId attempt=$attempt " +
                    "accountTail=${lease.username.takeLast(4)}"
            )
        }.onFailure { error ->
            Log.w(
                Tag,
                "CLIENT_SIP_LEASE_RELEASE_FAILED leaseTail=${lease.leaseId.takeLast(8)} " +
                    "accountTail=${lease.username.takeLast(4)} reason=${error.message}"
            )
            AppFileLogger.w(
                FileLogTag,
                "event=lease_release_failed traceId=$leaseTraceId attempt=$attempt " +
                    "accountTail=${lease.username.takeLast(4)} reason=${error.message}"
            )
        }
    }

    private fun logLeaseAcquired(
        request: AssistantCallRequest,
        lease: ClientSipLeaseResponse,
        traceId: String,
        attempt: Int
    ) {
        val message = "event=lease_acquired traceId=$traceId attempt=$attempt " +
            "accountTail=${lease.username.takeLast(4)} mode=${request.mode}"
        Log.i(Tag, message)
        AppFileLogger.i(FileLogTag, message)
    }

    private fun logInviteRetry(
        traceId: String,
        failedAttempt: Int,
        accountTail: String,
        statusCode: Int?,
        elapsedMs: Long,
        ringing: Boolean
    ) {
        val message = "event=invite_retry traceId=$traceId failedAttempt=$failedAttempt " +
            "nextAttempt=${failedAttempt + 1} accountTail=$accountTail statusCode=$statusCode " +
            "elapsedMs=$elapsedMs ringing=$ringing"
        Log.w(Tag, message)
        AppFileLogger.w(FileLogTag, message)
    }

    private fun logCallFailure(traceId: String, attempt: Int, error: Exception) {
        val message = "event=call_failed traceId=$traceId attempt=$attempt " +
            "reason=${error.message}"
        Log.w(Tag, message, error)
        AppFileLogger.w(FileLogTag, message, error)
    }

    private fun logTerminalFailure(
        traceId: String,
        attempt: Int,
        accountTail: String,
        failure: AssistantCallEngineEvent.Failure
    ) {
        val message = "event=terminal_failure traceId=$traceId attempt=$attempt " +
            "accountTail=$accountTail sipMethod=${failure.sipMethod} " +
            "statusCode=${failure.sipStatusCode} reason=${failure.message}"
        Log.w(Tag, message)
        AppFileLogger.w(FileLogTag, message)
    }

    private fun postEndedIfHangup(onEvent: (AssistantCallEngineEvent) -> Unit) {
        if (!released.get() && hangupRequested.get()) {
            mainHandler.post { onEvent(AssistantCallEngineEvent.Ended) }
        }
    }

    private fun ClientSipLeaseResponse.toAssistantSipAccount(): AssistantSipAccount =
        AssistantSipAccount(
            id = sipAccountId.ifBlank { username },
            server = server,
            port = port,
            username = username,
            password = password,
            callerNumber = callerNumber.ifBlank { username }
        )

    private fun leasePurpose(request: AssistantCallRequest): String =
        when (request.mode) {
            AssistantCallMode.NORMAL -> "normal_sip_call"
            AssistantCallMode.TRANSLATION -> "translation_call"
        }

    private fun leaseRoute(request: AssistantCallRequest): String {
        val normalized = request.phoneNumber.trim()
        val digits = normalized.filter(Char::isDigit)
        val countryCodeDigits = request.countryDialCode.filter(Char::isDigit)
        return if (
            normalized.startsWith("+") ||
            digits.startsWith("00") ||
            countryCodeDigits.isNotBlank() && countryCodeDigits != "86"
        ) {
            "international"
        } else {
            "domestic"
        }
    }

    private fun deviceId(): String =
        Settings.Secure.getString(appContext.contentResolver, Settings.Secure.ANDROID_ID)
            ?.takeIf(String::isNotBlank)
            ?: "android"

    private companion object {
        private const val Tag = "AssistantCallGateway"
        private const val FileLogTag = "CLIENT_SIP_CALL"
        private val ConnectedPhases = setOf(
            AssistantCallPhase.CONNECTED,
            AssistantCallPhase.TRANSLATING
        )
    }
}
