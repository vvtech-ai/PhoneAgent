package com.vvtech.aiassistant.features.assistant_ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssistantCallModelDisplayNamesTest {
    @Test
    fun qwenProductNameWinsOverStaleServerDisplayName() {
        assertEquals(
            "QwenOmniPlus",
            AssistantCallModelDisplayNames.resolve("QWEN_OMNI_PLUS", "QwenOmniFlash")
        )
        assertEquals(
            "QwenOmniPlus",
            AssistantCallModelDisplayNames.resolve("QWEN_OMNI_FLASH", "QwenOmniFlash")
        )
    }

    @Test
    fun serverDisplayNameWinsForKnownDoubaoProvider() {
        assertEquals(
            "服务端 Doubao 名称",
            AssistantCallModelDisplayNames.resolve("DOUBAO", "服务端 Doubao 名称")
        )
    }

    @Test
    fun knownProviderAliasesProvideProductFallbackWhenServerNameIsMissing() {
        assertEquals("QwenOmniPlus", AssistantCallModelDisplayNames.resolve("ALIBABA", null))
        assertEquals("QwenOmniPlus", AssistantCallModelDisplayNames.resolve("QWEN_OMNI_FLASH", null))
        assertEquals("Seeduplex", AssistantCallModelDisplayNames.resolve("VOLCANO", null))
    }

    @Test
    fun unknownProviderKeepsTrimmedBackendDisplayName() {
        assertEquals(
            "GPT Realtime",
            AssistantCallModelDisplayNames.resolve("GPT", "  GPT Realtime  ")
        )
        assertNull(AssistantCallModelDisplayNames.resolve("UNKNOWN", "  "))
    }
}
