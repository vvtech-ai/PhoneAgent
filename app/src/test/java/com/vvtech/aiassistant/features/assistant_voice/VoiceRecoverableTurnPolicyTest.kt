package com.vvtech.aiassistant.features.assistant_voice

import com.google.gson.JsonParser
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceRecoverableTurnPolicyTest {
    @Test
    fun committedAssistantWinsOverAnEarlierTerminationFact() {
        val events = listOf(
            event(StableConversationLedgerEventType.USER_TURN_ACCEPTED),
            event(StableConversationLedgerEventType.RUN_CANCELLED),
            event(StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED),
        )

        assertEquals(
            RecoverableVoiceTurnServerState.COMMITTED,
            resolveRecoverableVoiceTurnServerState(events, COMMAND_ID),
        )
    }

    @Test
    fun recoveryCancellationWinsOverAnAssistantThatCommittedLater() {
        val events = listOf(
            event(StableConversationLedgerEventType.USER_TURN_ACCEPTED),
            event(StableConversationLedgerEventType.RUN_CANCELLED).copy(
                sequence = 2,
                payload = JsonParser().parse("""{"stage":"recovery_revision"}""").asJsonObject,
            ),
            event(StableConversationLedgerEventType.ASSISTANT_TURN_COMMITTED).copy(sequence = 3),
        )

        assertEquals(
            RecoverableVoiceTurnServerState.TERMINATED,
            resolveRecoverableVoiceTurnServerState(events, COMMAND_ID),
        )
    }

    @Test
    fun acceptedTurnCanBeSupersededWhileUnknownTurnStartsFresh() {
        assertEquals(
            RecoverableVoiceTurnServerState.ACCEPTED,
            resolveRecoverableVoiceTurnServerState(
                listOf(event(StableConversationLedgerEventType.USER_TURN_ACCEPTED)),
                COMMAND_ID,
            ),
        )
        assertEquals(
            RecoverableVoiceTurnServerState.NOT_ACCEPTED,
            resolveRecoverableVoiceTurnServerState(emptyList(), COMMAND_ID),
        )
    }

    @Test
    fun transcriptMergeKeepsTheOldTextAndAvoidsDuplicatingRepeatedSpeech() {
        assertEquals("断网前内容 恢复后补充", mergeManualAsrTranscript("断网前内容", "恢复后补充"))
        assertEquals("断网前内容", mergeManualAsrTranscript("断网前内容", "断网前内容"))
        assertEquals("断网前内容继续", mergeManualAsrTranscript("断网前内容", "内容继续"))
    }

    private fun event(type: StableConversationLedgerEventType) = ConversationLedgerEvent(
        eventId = "event-${type.wireName}",
        sessionId = "session",
        sequence = 1,
        type = ConversationLedgerEventType.Known(type),
        schemaVersion = 1,
        idempotencyKey = "key-${type.wireName}",
        occurredAt = "2026-07-28T00:00:00Z",
        committedAt = "2026-07-28T00:00:01Z",
        commandId = COMMAND_ID,
        payload = JsonParser().parse("{}").asJsonObject,
    )

    private companion object {
        const val COMMAND_ID = "command"
    }
}
