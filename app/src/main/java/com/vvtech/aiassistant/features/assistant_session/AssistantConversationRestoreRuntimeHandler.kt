package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal data class AssistantConversationRestoreRuntimeDeps(
    val stateReader: AssistantConversationRestoreStateReader,
    val scope: CoroutineScope
)

internal class AssistantConversationRestoreRuntimeHandler(
    private val deps: AssistantConversationRestoreRuntimeDeps,
    private val callbacks: RestoreCallbacks,
    private val snapshotLoader: AssistantConversationRestoreSnapshotLoader,
    private val snapshotApplier: AssistantConversationRestoreSnapshotApplier
) {
    fun resumeTaskConversationForForeground() {
        val state = deps.stateReader.currentState()
        if (!state.voiceBackgroundPaused) {
            logRestore(
                eventType = "CONVERSATION_FOREGROUND_RESUME_SKIPPED",
                result = "skipped",
                reason = "voice_not_background_paused",
                taskId = state.taskId
            )
            return
        }
        logRestore(
            eventType = "CONVERSATION_FOREGROUND_RESUME_STARTED",
            result = "started",
            reason = "foreground_resume",
            taskId = state.taskId
        )
        callbacks.log(
            "resumeTaskConversationForForeground status=${state.status} " +
                "tts=${state.apiTtsPlaying || state.localTtsSpeaking} steps=${state.clarificationSteps.size}"
        )
        snapshotApplier.applyForegroundResume(
            listeningStatus = callbacks.localizedListeningStatus(),
            restoredStatus = RestoredConversationStatus
        )
        logRestore(
            eventType = "CONVERSATION_FOREGROUND_RESUME_COMPLETED",
            result = "completed",
            reason = "foreground_state_applied",
            taskId = state.taskId
        )
    }

    suspend fun syncConversationSnapshotForVoiceRecovery(
        sessionId: String,
        reason: String
    ): Boolean {
        if (sessionId.isBlank()) return true
        val startedAt = System.currentTimeMillis()
        logRestore("CONVERSATION_RECOVERY_SYNC_STARTED", "started", reason, sessionId)
        return runCatching {
            snapshotLoader.load(sessionId)
        }.map { snapshot ->
            applyConversationSnapshot(snapshot, reason).also {
                logRestore(
                    eventType = "CONVERSATION_RECOVERY_SYNC_COMPLETED",
                    result = if (it) "writable" else "read_only",
                    reason = reason,
                    sessionId = sessionId,
                    elapsedMs = System.currentTimeMillis() - startedAt
                )
            }
        }.getOrElse { throwable ->
            logRestore(
                eventType = "CONVERSATION_RECOVERY_SYNC_FAILED",
                result = "failed",
                reason = reason,
                sessionId = sessionId,
                elapsedMs = System.currentTimeMillis() - startedAt,
                throwable = throwable
            )
            AppFileLogger.w(
                "Index9VM",
                "sync conversation snapshot failed reason=$reason: ${throwable.message}"
            )
            snapshotApplier.applyVoiceRecoveryLoadFailure(
                tapMicToContinueStatus = callbacks.localizedTapMicToContinueStatus()
            )
            true
        }
    }

    fun resumeConversation(sessionId: String, onFinished: (() -> Unit)? = null) {
        val startedAt = System.currentTimeMillis()
        logRestore("CONVERSATION_RESTORE_STARTED", "started", "user_resume", sessionId)
        callbacks.setAgentSessionId(sessionId)
        deps.scope.launch {
            runCatching {
                snapshotLoader.load(sessionId)
            }.onSuccess { snapshot ->
                snapshotApplier.applyRestoredConversation(
                    snapshot = snapshot,
                    restoredStatus = RestoredConversationStatus,
                    idleStatus = callbacks.idleStatus()
                )
                onFinished?.invoke()
                logRestore(
                    "CONVERSATION_RESTORE_COMPLETED",
                    "completed",
                    "snapshot_applied",
                    sessionId,
                    elapsedMs = System.currentTimeMillis() - startedAt
                )
            }.onFailure { throwable ->
                logRestore(
                    "CONVERSATION_RESTORE_FAILED",
                    "failed",
                    "snapshot_load_failure",
                    sessionId,
                    elapsedMs = System.currentTimeMillis() - startedAt,
                    throwable = throwable
                )
                AppFileLogger.w("Index9VM", "resumeConversation failed: ${throwable.message}")
                snapshotApplier.applyRestoreFailure(
                    failureStatus = RestoreConversationFailureStatus
                )
                onFinished?.invoke()
            }
        }
    }

    private fun applyConversationSnapshot(
        snapshot: AssistantConversationRestoreSnapshot,
        reason: String
    ): Boolean {
        snapshotApplier.applyVoiceRecoverySnapshot(
            snapshot = snapshot,
            restoredStatus = RestoredConversationStatus
        )
        callbacks.log(
            "syncConversationSnapshotForVoiceRecovery reason=$reason session=${snapshot.sessionId} " +
                "status=${snapshot.resolvedStatus} readOnly=${snapshot.readOnly} " +
                "restoredSteps=${snapshot.steps.size}"
        )
        return !snapshot.readOnly
    }

    private fun logRestore(
        eventType: String,
        result: String,
        reason: String,
        sessionId: String? = null,
        taskId: String? = null,
        elapsedMs: Long? = null,
        throwable: Throwable? = null
    ) {
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.APP,
            eventType = eventType,
            sessionId = sessionId,
            taskId = taskId,
            result = result,
            reason = reason,
            elapsedMs = elapsedMs,
            attributes = mapOf("exceptionType" to throwable?.javaClass?.simpleName)
        )
        if (throwable == null) RuntimeStateLogger.info(event) else RuntimeStateLogger.warn(event, throwable)
    }
}

private const val RestoredConversationStatus = "对话已恢复，点击继续说话"
private const val RestoreConversationFailureStatus = "恢复对话失败"
