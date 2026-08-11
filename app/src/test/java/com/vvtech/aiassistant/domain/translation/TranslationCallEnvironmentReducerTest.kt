package com.vvtech.aiassistant.domain.translation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TranslationCallEnvironmentReducerTest {
    @Test
    fun `older patch cannot overwrite current environment`() {
        val current = environment(version = 4, network = available())
        val result = TranslationCallEnvironmentReducer.apply(
            current,
            TranslationCallEnvironmentPatch(
                version = 3,
                network = unavailable("late")
            )
        )

        assertEquals(current, result)
    }

    @Test
    fun `same version patch merges only supplied fields`() {
        val current = environment(
            version = 5,
            network = available(),
            sip = available(),
            model = pending(),
            riskMessage = "正在连接模型"
        )
        val result = TranslationCallEnvironmentReducer.apply(
            current,
            TranslationCallEnvironmentPatch(
                version = 5,
                phase = "model_ready",
                model = available(),
                clearRiskMessage = true,
                sampledAtMs = 50L
            )
        )

        assertEquals(available(), result.network)
        assertEquals(available(), result.sip)
        assertEquals(available(), result.model)
        assertEquals(TranslationEnvironmentState.Available, result.overallStatus)
        assertEquals("model_ready", result.phase)
        assertNull(result.riskMessage)
    }

    @Test
    fun `unavailable is worse than degraded and available`() {
        val result = TranslationCallEnvironmentReducer.apply(
            null,
            TranslationCallEnvironmentPatch(
                version = 1,
                network = degraded(),
                sip = unavailable("missing account"),
                model = available()
            )
        )

        assertEquals(TranslationEnvironmentState.Unavailable, result.overallStatus)
    }

    @Test
    fun `not applicable does not lower otherwise available environment`() {
        val result = TranslationCallEnvironmentReducer.apply(
            null,
            TranslationCallEnvironmentPatch(
                version = 1,
                network = available(),
                sip = notApplicable(),
                model = available()
            )
        )

        assertEquals(TranslationEnvironmentState.Available, result.overallStatus)
    }

    @Test
    fun `pending remains visible until every applicable component resolves`() {
        val result = TranslationCallEnvironmentReducer.apply(
            null,
            TranslationCallEnvironmentPatch(
                version = 1,
                network = available(),
                sip = pending(),
                model = available()
            )
        )

        assertEquals(TranslationEnvironmentState.Pending, result.overallStatus)
    }

    private fun environment(
        version: Long,
        network: TranslationEnvironmentComponent = pending(),
        sip: TranslationEnvironmentComponent = pending(),
        model: TranslationEnvironmentComponent = pending(),
        riskMessage: String? = null
    ) = TranslationCallEnvironment(
        version = version,
        phase = "preflight",
        overallStatus = TranslationCallEnvironmentReducer.worstOf(
            network.state,
            sip.state,
            model.state
        ),
        network = network,
        sip = sip,
        model = model,
        riskMessage = riskMessage,
        sampledAtMs = version
    )

    private fun pending() = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Pending
    )

    private fun available() = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Available
    )

    private fun degraded() = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Degraded
    )

    private fun unavailable(detail: String) = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Unavailable,
        detail = detail
    )

    private fun notApplicable() = TranslationEnvironmentComponent(
        TranslationEnvironmentState.NotApplicable
    )
}
