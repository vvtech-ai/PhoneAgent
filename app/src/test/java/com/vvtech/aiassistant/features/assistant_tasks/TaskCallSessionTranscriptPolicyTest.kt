package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.viewmodel.parseCallDialogueDetail as legacyParseCallDialogueDetail
import com.vvtech.aiassistant.features.assistant.viewmodel.parseCallSessionUpdatedAt as legacyParseCallSessionUpdatedAt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionTranscriptPolicyTest {
    @Test
    fun parsesDialogueRolesAndIgnoresUnknownLines() {
        val lines = parseTaskCallDialogueDetail(
            """
            assistant: 你好，是北海渔村吗？
            callee: 是的
            merchant: 有包间
            remote: 尾号 9131
            system: ignored
            assistant:
            """.trimIndent()
        )

        assertEquals(
            listOf(
                TranscriptLine(TranscriptRole.Assistant, "你好，是北海渔村吗？"),
                TranscriptLine(TranscriptRole.Remote, "是的"),
                TranscriptLine(TranscriptRole.Remote, "有包间"),
                TranscriptLine(TranscriptRole.Remote, "尾号 9131")
            ),
            lines
        )
        assertTrue(lines.all(::taskCallSessionIsStreamingDialogueLine))
    }

    @Test
    fun parsesUpdatedAtWithLegacyCompatibleLocalDateTimeSemantics() {
        assertEquals(2026, parseTaskCallSessionUpdatedAt("2026-06-11T16:30:00")?.year)
        assertNull(parseTaskCallSessionUpdatedAt("2026-06-11T16:30:00Z"))
        assertNull(parseTaskCallSessionUpdatedAt(""))
    }

    @Test
    fun emptyDialogueKeepsTranscriptAndClearsLastAppliedDialogue() {
        val current = listOf(TranscriptLine(TranscriptRole.Note, "正在发起电话..."))

        val result = mergeTaskCallSessionTranscript(
            currentTranscript = current,
            previousDialogueDetail = "assistant: 你好",
            dialogueDetail = ""
        )

        assertEquals(current, result.transcript)
        assertNull(result.lastAppliedDialogueDetail)
    }

    @Test
    fun fullReplacementPreservesSeedLinesAndDeduplicatesIncomingLines() {
        val current = listOf(
            TranscriptLine(TranscriptRole.Note, "正在发起电话..."),
            TranscriptLine(TranscriptRole.Assistant, "你好，是北海渔村吗？")
        )
        val detail = """
            assistant: 你好，是北海渔村吗？
            callee: 是的
        """.trimIndent()

        val result = mergeTaskCallSessionTranscript(
            currentTranscript = current,
            previousDialogueDetail = "assistant: 旧内容",
            dialogueDetail = detail
        )

        assertEquals(
            listOf(
                TranscriptLine(TranscriptRole.Note, "正在发起电话..."),
                TranscriptLine(TranscriptRole.Assistant, "你好，是北海渔村吗？"),
                TranscriptLine(TranscriptRole.Remote, "是的")
            ),
            result.transcript
        )
        assertEquals(detail, result.lastAppliedDialogueDetail)
    }

    @Test
    fun incrementalDialogueAppendsOnlyNewLines() {
        val previous = "assistant: 你好，是北海渔村吗？"
        val current = listOf(TranscriptLine(TranscriptRole.Assistant, "你好，是北海渔村吗？"))
        val detail = """
            assistant: 你好，是北海渔村吗？
            callee: 是的
        """.trimIndent()

        val result = mergeTaskCallSessionTranscript(
            currentTranscript = current,
            previousDialogueDetail = previous,
            dialogueDetail = detail
        )

        assertEquals(
            listOf(
                TranscriptLine(TranscriptRole.Assistant, "你好，是北海渔村吗？"),
                TranscriptLine(TranscriptRole.Remote, "是的")
            ),
            result.transcript
        )
        assertEquals(detail, result.lastAppliedDialogueDetail)
    }

    @Test
    fun sameDialogueDoesNotAppendAgain() {
        val previous = "assistant: 你好，是北海渔村吗？"
        val current = listOf(TranscriptLine(TranscriptRole.Assistant, "你好，是北海渔村吗？"))

        val result = mergeTaskCallSessionTranscript(
            currentTranscript = current,
            previousDialogueDetail = previous,
            dialogueDetail = previous
        )

        assertEquals(current, result.transcript)
        assertEquals(previous, result.lastAppliedDialogueDetail)
    }

    @Test
    fun legacyViewModelHelpersDelegateToTaskPolicy() {
        val detail = "assistant: 你好\ncallee: 是的"

        assertEquals(parseTaskCallDialogueDetail(detail), legacyParseCallDialogueDetail(detail))
        assertEquals(
            parseTaskCallSessionUpdatedAt("2026-06-11T16:30:00"),
            legacyParseCallSessionUpdatedAt("2026-06-11T16:30:00")
        )
    }
}
