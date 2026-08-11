package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DialRecentCallDataSourceBoundaryGuardTest {
    @Test
    fun recentCallsCombineSystemAndTranslationSources() {
        val policy = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/DialRecentCallPolicy.kt"
        ).readText(Charsets.UTF_8)
        val sheet = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantCallsDialSheet.kt"
        ).readText(Charsets.UTF_8)
        val dataSource = sourceFile(
            "src/main/java/com/vvtech/aiassistant/data/local/calllog/DeviceCallLogDataSource.kt"
        ).readText(Charsets.UTF_8)
        val manifest = sourceFile("src/main/AndroidManifest.xml").readText(Charsets.UTF_8)

        assertTrue(policy.contains("translationDialRecentCallRecords"))
        assertTrue(policy.contains("localDialRecentCalls"))
        assertTrue(sheet.contains("rememberDeviceCallLogState"))
        assertTrue(sheet.contains("mergeDialRecentCalls"))
        assertTrue(dataSource.contains("CallLog.Calls.CONTENT_URI"))
        assertTrue(manifest.contains("android.permission.READ_CALL_LOG"))
        assertFalse(manifest.contains("tools:node=\"remove\""))
    }

    private companion object {
        fun sourceFile(path: String): File = listOf(
            File(path),
            File("android/app/$path")
        ).first { it.exists() }
    }
}
