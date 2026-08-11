package com.vvtech.aiassistant.features.assistant_calls

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DialTranslationLanguagePolicyTest {
    @Test
    fun dialerLabelsMapToTranslationRequestLanguageCodes() {
        assertEquals(
            DialTranslationLanguageCodes(caller = "zh", callee = "ja"),
            dialTranslationLanguageCodes(myLanguage = "中文", otherLanguage = "日语")
        )
        assertEquals(
            DialTranslationLanguageCodes(caller = "fr", callee = "de"),
            dialTranslationLanguageCodes(myLanguage = "法语", otherLanguage = "德语")
        )
    }

    @Test
    fun unknownLabelsUseStableCallerAndCalleeDefaults() {
        assertEquals(
            DialTranslationLanguageCodes(caller = "zh", callee = "en"),
            dialTranslationLanguageCodes(myLanguage = "unknown", otherLanguage = "unknown")
        )
    }

    @Test
    fun translationRuntimeReceivesDialerLanguageCodes() {
        val runtimeGraph = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(runtimeGraph.contains("dialTranslationLanguageCodes("))
        assertTrue(runtimeGraph.contains("myLanguage = callDialState.dialer.myLanguage"))
        assertTrue(runtimeGraph.contains("otherLanguage = callDialState.dialer.otherLanguage"))
        assertTrue(runtimeGraph.contains("callerLanguage = languages.caller"))
        assertTrue(runtimeGraph.contains("calleeLanguage = languages.callee"))
    }

    private fun sourceFile(path: String): File {
        return listOf(File(path), File("android/app/$path")).first { it.exists() }
    }
}
