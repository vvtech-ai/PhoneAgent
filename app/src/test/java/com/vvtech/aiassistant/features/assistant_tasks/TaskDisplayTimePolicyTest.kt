package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.FINAL_TASK_CLOCK_TIME_REGEX as legacyFinalTaskClockTimeRegex
import com.vvtech.aiassistant.features.assistant.FINAL_TASK_NATURAL_TIME_REGEX as legacyFinalTaskNaturalTimeRegex
import com.vvtech.aiassistant.features.assistant.FINAL_TASK_TIME_REGEX as legacyFinalTaskTimeRegex
import com.vvtech.aiassistant.features.assistant.FinalTaskRecord
import com.vvtech.aiassistant.features.assistant.extractFinalTaskInstant as legacyExtractFinalTaskInstant
import com.vvtech.aiassistant.features.assistant.fallbackFinalTaskTimeLabel as legacyFallbackFinalTaskTimeLabel
import com.vvtech.aiassistant.features.assistant.finalTaskRecordSortInstant as legacyFinalTaskRecordSortInstant
import com.vvtech.aiassistant.features.assistant.finalTaskRelativeTimeLabel as legacyFinalTaskRelativeTimeLabel
import com.vvtech.aiassistant.features.assistant.normalizeFinalTaskTimeText as legacyNormalizeFinalTaskTimeText
import com.vvtech.aiassistant.features.assistant.parseFinalTaskTime as legacyParseFinalTaskTime
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskDisplayTimePolicyTest {
    @Test
    fun formatsRelativeLabelsFromIsoTime() {
        val today = LocalDate.of(2026, 6, 11)
        val zoneId = ZoneId.of("UTC")

        assertEquals("今天 10:30", taskDisplayRelativeTimeLabel("2026-06-11T10:30:00Z", today, zoneId))
        assertEquals("昨天 23:59", taskDisplayRelativeTimeLabel("2026-06-10T23:59:00Z", today, zoneId))
        assertEquals("6月1日 08:00", taskDisplayRelativeTimeLabel("2026-06-01T08:00:00Z", today, zoneId))
    }

    @Test
    fun usesFirstRecordTimeAsSortInstant() {
        val sortInstant = taskDisplayRecordSortInstant(
            startedAt = "",
            detail = "结果 2026-06-11T10:30:00Z",
            sourceText = "原始 2026-06-12T10:30:00Z",
            title = "标题",
            scheduledAt = "2026-06-13T10:30:00Z"
        )

        assertEquals(Instant.parse("2026-06-11T10:30:00Z"), sortInstant)
        assertEquals(Instant.parse("2026-06-11T10:30:00Z").toEpochMilli(), taskDisplaySortEpochMillis(sortInstant))
    }

    @Test
    fun normalizesNaturalTimeTextAndFallbackLabel() {
        assertEquals("明天 18:30", normalizeTaskDisplayTimeText("明天 18：30"))
        assertEquals("明天18点", fallbackTaskDisplayTimeLabel("请明天18点联系"))
        assertEquals("明天18点", taskDisplayStartTimeLabel("", "请明天18点联系"))
    }

    @Test
    fun legacyFinalTaskEntrypointsDelegateToTaskDisplayPolicy() {
        val rawTime = "2026-06-11T10:30:00Z"
        val today = LocalDate.of(2026, 6, 11)
        val zoneId = ZoneId.of("UTC")
        val record = FinalTaskRecord(
            title = "订餐任务",
            status = "COMPLETED",
            detail = "完成 $rawTime",
            sourceText = "",
            startedAt = ""
        )

        assertEquals(taskDisplayRelativeTimeLabel(rawTime, today, zoneId), legacyFinalTaskRelativeTimeLabel(rawTime, today, zoneId))
        assertEquals(extractTaskDisplayInstant(rawTime), legacyExtractFinalTaskInstant(rawTime))
        assertEquals(parseTaskDisplayTime(rawTime), legacyParseFinalTaskTime(rawTime))
        assertEquals(fallbackTaskDisplayTimeLabel("明天18点"), legacyFallbackFinalTaskTimeLabel("明天18点"))
        assertEquals(normalizeTaskDisplayTimeText("明天 18：30"), legacyNormalizeFinalTaskTimeText("明天 18：30"))
        assertEquals(taskDisplayRecordSortInstant("", record.detail, "", record.title, ""), legacyFinalTaskRecordSortInstant(record))
        assertSame(TASK_DISPLAY_TIME_REGEX, legacyFinalTaskTimeRegex)
        assertSame(TASK_DISPLAY_NATURAL_TIME_REGEX, legacyFinalTaskNaturalTimeRegex)
        assertSame(TASK_DISPLAY_CLOCK_TIME_REGEX, legacyFinalTaskClockTimeRegex)
    }

    @Test
    fun legacyFilesKeepOnlyCompatibilityBridgeForTimePolicy() {
        val textPolicy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalTaskTextPolicy.kt"
        ).readText()
        val uiHelpers = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/FinalUiHelpers.kt"
        ).readText()

        assertTrue(textPolicy.contains("extractTaskDisplayInstant(raw)"))
        assertTrue(textPolicy.contains("FINAL_TASK_TIME_REGEX = TASK_DISPLAY_TIME_REGEX"))
        assertFalse(textPolicy.contains("LocalDateTime.parse("))
        assertFalse(textPolicy.contains("OffsetDateTime.parse("))
        assertTrue(uiHelpers.contains("taskDisplayRecordSortInstant("))
        assertFalse(uiHelpers.contains("firstNotNullOfOrNull { extractFinalTaskInstant(it) }"))
    }

    private fun sourceFile(path: String): File {
        return listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
