package com.vvtech.aiassistant.features.assistant_session

import com.google.gson.Gson
import com.google.gson.JsonParser
import com.vvtech.aiassistant.data.repository.timeline.ConversationTimelineSnapshot
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.ConversationTimelineProjection
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType
import com.vvtech.aiassistant.features.assistant_timeline.LedgerTimelineState
import com.vvtech.aiassistant.model.ConversationDetail
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantConversationRestoreSnapshotMapperTest {
    @Test
    fun ocrOnlyTimelineWithRuntimeNullTitleBuildsRestorableSnapshot() {
        val runtimeNullTitleDetail = Gson().fromJson(
            """{"sessionId":"ocr-only-session","title":null,"status":"RUNNING"}""",
            ConversationDetail::class.java,
        )
        val ocrEvent = ledgerEvent(
            sequence = 1,
            type = StableConversationLedgerEventType.OCR_IMAGE_COMMITTED,
            payload = """{"attachmentId":"ocr-1","anchorStepCount":0,"createdOrdinal":0}""",
        )

        val snapshot = buildAssistantConversationRestoreSnapshot(
            detail = runtimeNullTitleDetail,
            timeline = ConversationTimelineSnapshot(
                sessionId = "ocr-only-session",
                ledgerHeadSequence = 1,
                events = listOf(ocrEvent),
                projection = ConversationTimelineProjection(
                    conversationStatus = "RUNNING",
                    conversationContinuable = true,
                    pendingToolRestorable = false,
                    migrationStatus = "LEDGER_NATIVE",
                    projectedThroughSequence = 1,
                ),
                timeline = LedgerTimelineState(cursor = 1),
            ),
        )

        assertEquals("ocr-only-session", snapshot.sessionId)
        assertEquals("", snapshot.title)
        assertTrue(snapshot.conversationContinuable)
    }

    @Test
    fun timelineSnapshotCarriesServerProjectionWithoutLegacyParsing() {
        val snapshot = buildAssistantConversationRestoreSnapshot(
            detail = detail(status = "WAITING_FOR_TOOL"),
            timeline = ConversationTimelineSnapshot(
                sessionId = "session-1",
                ledgerHeadSequence = 7,
                events = emptyList(),
                projection = ConversationTimelineProjection(
                    conversationStatus = "WAITING_FOR_TOOL",
                    conversationContinuable = false,
                    pendingToolRestorable = true,
                    migrationStatus = "LEDGER_NATIVE",
                    projectedThroughSequence = 7,
                ),
                timeline = LedgerTimelineState(),
            ),
        )

        assertEquals("WAITING_FOR_TOOL", snapshot.resolvedStatus)
        assertFalse(snapshot.conversationContinuable)
        assertFalse(snapshot.canRestorePending)
        assertTrue(snapshot.steps.isEmpty())
        assertTrue(snapshot.timeline.timelineItems.isEmpty())
    }

    @Test
    fun unavailableOrNoLedgerFallbackIsExplicitReadOnlyEmptyView() {
        val snapshot = buildAssistantConversationRestoreSnapshot(
            detail = detail(status = "RUNNING"),
            rawStatus = "RUNNING",
        )

        assertTrue(snapshot.readOnly)
        assertFalse(snapshot.conversationContinuable)
        assertFalse(snapshot.pendingToolRestorable)
        assertFalse(snapshot.canRestorePending)
        assertTrue(snapshot.steps.isEmpty())
        assertTrue(snapshot.timeline.timelineItems.isEmpty())
        assertNull(snapshot.pendingToolCallId)
        assertNull(snapshot.agentQuestions)
        assertNull(snapshot.agentCallSpec)
        assertNull(snapshot.callResult)
    }

    @Test
    fun restorableMakeCallKeepsOnlyClientSafeConfirmationFields() {
        val requested = ledgerEvent(
            sequence = 1,
            type = StableConversationLedgerEventType.TOOL_REQUESTED,
            payload = """{
                "modelTurnId":"turn-1","toolCallId":"call-tool-1","toolName":"makeCall","ordinal":0,
                "arguments":{"phoneNumber":"13800138000","scene":"RESTAURANT_BOOKING",
                "targetName":"北海渔村","primaryGoal":"今晚八点订四人位",
                "summaryLines":["人数：4"],"negotiationRules":["可接受八点半"],"boundaries":["不要室外位"]}
            }""",
        )
        val snapshot = buildAssistantConversationRestoreSnapshot(
            detail = detail(status = "WAITING_FOR_TOOL"),
            timeline = ConversationTimelineSnapshot(
                sessionId = "session-1",
                ledgerHeadSequence = 1,
                events = listOf(requested),
                projection = ConversationTimelineProjection(
                    conversationStatus = "WAITING_FOR_TOOL",
                    conversationContinuable = true,
                    pendingToolRestorable = true,
                    migrationStatus = "LEDGER_NATIVE",
                    projectedThroughSequence = 1,
                ),
                timeline = LedgerTimelineState(cursor = 1),
            ),
        )

        assertEquals("call-tool-1", snapshot.pendingToolCallId)
        assertEquals("北海渔村", snapshot.agentCallSpec?.targetName)
        assertEquals("今晚八点订四人位", snapshot.agentCallSpec?.primaryGoal)
        assertEquals(listOf("人数：4"), snapshot.agentCallSpec?.summaryLines)
    }

    @Test
    fun productionRestoreHasNoLegacyCanonicalReader() {
        val sourceRoot = File("src/main/java/com/vvtech/aiassistant")
        val hits = sourceRoot.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .filter { it.readText().contains("messagesJson") }
            .map { it.relativeTo(sourceRoot).invariantSeparatorsPath }
            .toList()

        assertTrue("legacy Android readers remain: $hits", hits.isEmpty())
        assertFalse(File(sourceRoot, "features/assistant_session/AssistantSessionResumeStateParser.kt").exists())
        assertFalse(File(sourceRoot, "features/assistant_session/AssistantSessionTimelineRestoreMapper.kt").exists())
        assertFalse(File(sourceRoot, "features/assistant_tasks/TaskBatchCallReceiptRestore.kt").exists())
        assertFalse(File(sourceRoot, "features/assistant/FinalConversationOutcomePolicy.kt").exists())
    }

    private fun detail(status: String): ConversationDetail = ConversationDetail(
        sessionId = "session-1",
        title = "北海渔村",
        status = status,
        sceneType = "RESTAURANT_BOOKING",
        updatedAt = "2026-06-10 18:30",
    )

    private fun ledgerEvent(
        sequence: Long,
        type: StableConversationLedgerEventType,
        payload: String,
    ) = ConversationLedgerEvent(
        eventId = "event-$sequence",
        sessionId = "session-1",
        sequence = sequence,
        type = ConversationLedgerEventType.Known(type),
        schemaVersion = 1,
        idempotencyKey = "key-$sequence",
        occurredAt = "2026-07-21T00:00:00Z",
        committedAt = "2026-07-21T00:00:01Z",
        payload = JsonParser().parse(payload).asJsonObject,
    )
}
