package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BackendTranslationEnvironmentProtocolTest {
    @Test
    fun `parses versioned component state and diagnostics`() {
        val patch = BackendTranslationEnvironmentProtocol.parse(
            JSONObject(
                """
                {
                  "version":12,
                  "phase":"media_ready",
                  "network":{"state":"degraded","latencyMs":420,"detail":"weak"},
                  "sip":{"state":"available"},
                  "model":{"state":"unavailable"},
                  "riskMessage":"model unavailable",
                  "sampledAtMs":12345
                }
                """.trimIndent()
            )
        )

        assertEquals(12L, patch?.version)
        assertEquals(TranslationEnvironmentState.Degraded, patch?.network?.state)
        assertEquals(420L, patch?.network?.latencyMs)
        assertEquals(TranslationEnvironmentState.Unavailable, patch?.model?.state)
        assertEquals("model unavailable", patch?.riskMessage)
    }

    @Test
    fun `rejects missing version`() {
        assertNull(
            BackendTranslationEnvironmentProtocol.parse(
                JSONObject("""{"network":{"state":"available"}}""")
            )
        )
    }
}
