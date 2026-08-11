package com.vvtech.aiassistant.callengine

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTranslationIntroResponseBoundaryTest {
    @Test
    fun `delayed trigger response stays muted after live input resumes`() {
        val gate = AssistantTranslationIntroGate()
        val inputReleased = CountDownLatch(1)
        val completed = CountDownLatch(1)
        val coordinator = coordinator(
            gate = gate,
            logger = { line ->
                if (line.contains("event=input_released")) inputReleased.countDown()
                if (line.contains("event=completed")) completed.countDown()
            }
        )

        coordinator.markModelReady()
        assertTrue(coordinator.start())
        assertTrue(inputReleased.await(1, TimeUnit.SECONDS))
        assertFalse(gate.shouldSuppressLiveInput())
        assertTrue(gate.shouldSuppressModelOutput())

        coordinator.markModelTriggerResponseDone()

        assertTrue(completed.await(1, TimeUnit.SECONDS))
        assertFalse(gate.shouldSuppressModelOutput())
        coordinator.close()
    }

    @Test
    fun `missing trigger response boundary fails closed after timeout`() {
        val gate = AssistantTranslationIntroGate()
        val logs = Collections.synchronizedList(mutableListOf<String>())
        val failed = CountDownLatch(1)
        val coordinator = coordinator(
            gate = gate,
            triggerResponseTimeoutMs = 10L,
            logger = { line ->
                logs += line
                if (line.contains("event=failed")) failed.countDown()
            }
        )

        coordinator.markModelReady()
        assertTrue(coordinator.start())

        assertTrue(failed.await(1, TimeUnit.SECONDS))
        assertTrue(logs.any { it.contains("reason=model_trigger_response_timeout") })
        assertTrue(gate.shouldSuppressLiveInput())
        assertTrue(gate.shouldSuppressModelOutput())
        coordinator.close()
        assertFalse(gate.shouldSuppressLiveInput())
        assertFalse(gate.shouldSuppressModelOutput())
    }

    private fun coordinator(
        gate: AssistantTranslationIntroGate,
        triggerResponseTimeoutMs: Long = 5_000L,
        logger: (String) -> Unit
    ) = AssistantTranslationIntroCoordinator(
        spec = AssistantTranslationIntroSpec("zh-CN", "en-US", "qwen", "trace-boundary"),
        callbacks = AssistantTranslationIntroCallbacks(
            playLocalFrame = {},
            playRemoteFrames = {},
            sendModelLocalFrame = {},
            isCallActive = { true },
            onFailure = {}
        ),
        gate = gate,
        loadFrames = { listOf(ShortArray(320)) },
        loadTriggerFrames = { listOf(ShortArray(320) { 9 }) },
        expectTriggerResponseBoundary = true,
        triggerResponseTimeoutMs = triggerResponseTimeoutMs,
        sleeper = {},
        logger = logger
    )
}
