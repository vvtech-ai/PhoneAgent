package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.core.model.AgentCommandIdentity
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineRepository
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType

internal enum class RecoverableVoiceTurnServerState {
    NOT_ACCEPTED,
    ACCEPTED,
    TERMINATED,
    COMMITTED,
}

internal data class RecoverableVoiceTurnSubmissionPlan(
    val text: String,
    val appendUserStep: Boolean,
    val replaceLastUserStep: Boolean,
    val supersedesCommandId: String? = null,
    val originalAlreadyCommitted: Boolean = false,
    val submitAfterOriginalCommit: Boolean = false,
)

internal class VoiceTurnRecoveryUnavailableException(cause: Throwable) :
    IllegalStateException("voice turn recovery state unavailable", cause)

/**
 * Owns the single recoverable voice-turn fact. ASR callback dedup remains in
 * [VoiceRecognizedInputDedupTracker]; this coordinator only handles business-turn recovery.
 */
internal class VoiceRecoverableTurnCoordinator(
    private val timelineRepository: ConversationTimelineRepository,
    private val accountIdProvider: () -> String,
    private val log: (String) -> Unit,
) {
    private data class TrackedTurn(
        val sessionId: String,
        val identity: AgentCommandIdentity,
        val text: String,
    )

    private var activeTurn: TrackedTurn? = null
    private var recoverableTurn: TrackedTurn? = null

    fun onCommandStarted(
        sessionId: String,
        identity: AgentCommandIdentity,
        text: String,
    ) {
        activeTurn = TrackedTurn(sessionId, identity, text.trim())
        recoverableTurn = null
        logState(
            event = "VOICE_TURN_RECOVERY_COMMAND_STARTED",
            turn = activeTurn,
            reason = "agent_stream_started",
        )
    }

    fun onNetworkFailure() {
        val turn = activeTurn ?: return
        recoverableTurn = turn
        activeTurn = null
        logState(
            event = "VOICE_TURN_RECOVERY_FROZEN",
            turn = turn,
            reason = "transport_failure",
        )
    }

    fun onCommandCompleted(commandId: String) {
        if (activeTurn?.identity?.commandId != commandId) return
        logState(
            event = "VOICE_TURN_RECOVERY_COMMAND_COMPLETED",
            turn = activeTurn,
            reason = "agent_stream_completed",
        )
        activeTurn = null
        recoverableTurn = null
    }

    fun recoverableBaseText(): String? =
        recoverableTurn?.text?.trim()?.takeIf(String::isNotBlank)

    fun clear(reason: String) {
        val turn = recoverableTurn ?: activeTurn
        activeTurn = null
        recoverableTurn = null
        logState("VOICE_TURN_RECOVERY_CLEARED", turn, reason)
    }

    suspend fun planSubmission(recognizedText: String): RecoverableVoiceTurnSubmissionPlan {
        val candidate = recognizedText.trim()
        val pending = recoverableTurn
            ?: return RecoverableVoiceTurnSubmissionPlan(
                text = candidate,
                appendUserStep = true,
                replaceLastUserStep = false,
            )
        val serverState = try {
            resolveServerState(pending)
        } catch (failure: Throwable) {
            logState(
                event = "VOICE_TURN_RECOVERY_RECONCILE_FAILED",
                turn = pending,
                reason = failure.javaClass.simpleName,
            )
            throw VoiceTurnRecoveryUnavailableException(failure)
        }
        if (serverState == RecoverableVoiceTurnServerState.COMMITTED) {
            val repeatedOriginal = mergeManualAsrTranscript(pending.text, candidate) == pending.text
            logState(
                event = "VOICE_TURN_RECOVERY_ORIGINAL_COMMITTED",
                turn = pending,
                reason = if (repeatedOriginal) {
                    "assistant_turn_committed_repeated_input"
                } else {
                    "assistant_turn_committed_new_followup"
                },
            )
            return RecoverableVoiceTurnSubmissionPlan(
                text = candidate,
                appendUserStep = !repeatedOriginal,
                replaceLastUserStep = false,
                originalAlreadyCommitted = true,
                submitAfterOriginalCommit = !repeatedOriginal,
            )
        }
        val merged = mergeManualAsrTranscript(pending.text, candidate)
        val supersedes = pending.identity.commandId
        logState(
            event = "VOICE_TURN_RECOVERY_REVISION_PLANNED",
            turn = pending,
            reason = serverState.name.lowercase(),
        )
        return RecoverableVoiceTurnSubmissionPlan(
            text = merged,
            appendUserStep = false,
            replaceLastUserStep = true,
            supersedesCommandId = supersedes,
        )
    }

    private suspend fun resolveServerState(turn: TrackedTurn): RecoverableVoiceTurnServerState {
        val events = timelineRepository.sync(accountIdProvider(), turn.sessionId).events
        return resolveRecoverableVoiceTurnServerState(events, turn.identity.commandId)
    }

    private fun logState(event: String, turn: TrackedTurn?, reason: String) {
        log(
            "$event sessionId=${turn?.sessionId.orEmpty()} " +
                "commandId=${turn?.identity?.commandId.orEmpty()} " +
                "traceId=${turn?.identity?.traceId.orEmpty()} reason=$reason " +
                "textLength=${turn?.text?.length ?: 0}"
        )
    }
}

internal fun resolveRecoverableVoiceTurnServerState(
    events: List<ConversationLedgerEvent>,
    commandId: String,
): RecoverableVoiceTurnServerState {
    val commandEvents = events.filter { it.commandId == commandId }
    fun has(type: StableConversationLedgerEventType): Boolean =
        commandEvents.any { (it.type as? ConversationLedgerEventType.Known)?.stable == type }
    val recoveryCancellationSequence = commandEvents
        .filter {
            (it.type as? ConversationLedgerEventType.Known)?.stable ==
                StableConversationLedgerEventType.RUN_CANCELLED &&
                it.payload.get("stage")
                    ?.takeIf { value -> value.isJsonPrimitive }
                    ?.asString == "recovery_revision"
        }
        .minOfOrNull(ConversationLedgerEvent::sequence)
    val authoritativeAssistant = commandEvents.any {
        (it.type as? ConversationLedgerEventType.Known)?.stable ==
            StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED &&
            (recoveryCancellationSequence == null || it.sequence < recoveryCancellationSequence)
    }
    return when {
        authoritativeAssistant ->
            RecoverableVoiceTurnServerState.COMMITTED
        has(StableConversationLedgerEventType.RUN_CANCELLED) ||
            has(StableConversationLedgerEventType.RUN_FAILED) ->
            RecoverableVoiceTurnServerState.TERMINATED
        has(StableConversationLedgerEventType.USER_TURN_ACCEPTED) ->
            RecoverableVoiceTurnServerState.ACCEPTED
        else -> RecoverableVoiceTurnServerState.NOT_ACCEPTED
    }
}
