package com.vvtech.aiassistant.domain.translation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallRoutePolicyTest {
    private val preferences = TranslationCallPreferences(
        domesticProvider = TranslationRealtimeProvider.Qwen,
        overseasProvider = TranslationRealtimeProvider.Gemini,
        domesticSipAccountId = "21311780",
        internationalSipAccountId = "1008",
        serviceRegion = TranslationServiceRegion.UnitedStates
    )

    @Test
    fun `china location and local mobile uses domestic sip`() {
        val plan = readyPlan(china(), "13800138000", "+86")

        assertEquals("+8613800138000", plan.targetE164)
        assertEquals("13800138000", plan.networkDialNumber)
        assertEquals(TranslationCallTransport.LocalSipDomestic, plan.transport)
        assertEquals("21311780", plan.sipAccountId)
        assertEquals(TranslationRealtimeProvider.Qwen, plan.provider)
    }

    @Test
    fun `china landline and service numbers use domestic sip`() {
        val landline = readyPlan(china(), "01088886666", "+86")
        val service = readyPlan(china(), "4001234567", "+86")

        assertEquals("+861088886666", landline.targetE164)
        assertEquals("01088886666", landline.networkDialNumber)
        assertEquals(TranslationCallTransport.LocalSipDomestic, landline.transport)
        assertEquals("4001234567", service.targetE164)
        assertEquals("4001234567", service.networkDialNumber)
        assertEquals(TranslationCallTransport.LocalSipDomestic, service.transport)
    }

    @Test
    fun `china extension is planned as post connect dtmf`() {
        val plan = readyPlan(china(), "01088886666转1234", "+86")

        assertEquals("01088886666", plan.networkDialNumber)
        assertEquals("1234", plan.postConnectDtmf)
    }

    @Test
    fun `china location and overseas number uses international sip`() {
        val plan = readyPlan(china(), "+81333445111", "+86")

        assertEquals(TranslationCallTransport.LocalSipInternational, plan.transport)
        assertEquals("1008", plan.sipAccountId)
        assertEquals(TranslationRealtimeProvider.Qwen, plan.provider)
    }

    @Test
    fun `overseas location and china number still uses backend webrtc`() {
        val plan = readyPlan(overseas("US"), "+8613800138000", "+1")

        assertEquals(TranslationCallTransport.BackendWebRtc, plan.transport)
        assertNull(plan.sipAccountId)
        assertEquals(TranslationRealtimeProvider.Gemini, plan.provider)
    }

    @Test
    fun `overseas location and international number uses backend webrtc`() {
        val plan = readyPlan(overseas("JP"), "09012345678", "+81")

        assertEquals("+819012345678", plan.targetE164)
        assertEquals(TranslationCallTransport.BackendWebRtc, plan.transport)
    }

    @Test
    fun `unresolved location fails before routing`() {
        val result = TranslationCallRoutePolicy.plan(
            TranslationRegionState.Unavailable("未获得定位权限"),
            "+8613800138000",
            "+86",
            preferences
        )

        assertEquals(
            TranslationCallPlanFailure.LocationUnavailable,
            (result as TranslationCallPlanResult.Failed).reason
        )
    }

    @Test
    fun `invalid number fails before routing`() {
        val result = TranslationCallRoutePolicy.plan(china(), "12", "+86", preferences)

        assertEquals(
            TranslationCallPlanFailure.InvalidNumber,
            (result as TranslationCallPlanResult.Failed).reason
        )
    }

    @Test
    fun `twelve digit china mobile fails before routing`() {
        val result = TranslationCallRoutePolicy.plan(
            china(),
            "159158743619",
            "+86",
            preferences
        )

        assertEquals(
            TranslationCallPlanFailure.InvalidNumber,
            (result as TranslationCallPlanResult.Failed).reason
        )
    }

    @Test
    fun `provider sets are enforced by location`() {
        val invalid = preferences.copy(
            domesticProvider = TranslationRealtimeProvider.OpenAi
        )
        val result = TranslationCallRoutePolicy.plan(
            china(),
            "+8613800138000",
            "+86",
            invalid
        )

        assertEquals(
            TranslationCallPlanFailure.InvalidDomesticProvider,
            (result as TranslationCallPlanResult.Failed).reason
        )
    }

    @Test
    fun `normalizer supports international access prefix and rejects malformed values`() {
        assertEquals(
            "+81333445111",
            TranslationCallRoutePolicy.normalizeE164("00 81 3 3344 5111", "+86")
        )
        assertNull(TranslationCallRoutePolicy.normalizeE164("++86 138", "+86"))
        assertTrue(
            TranslationCallRoutePolicy.normalizeE164("(138) 0013-8000", "+86")
                ?.startsWith("+86") == true
        )
    }

    private fun readyPlan(
        region: TranslationRegionState,
        number: String,
        dialCode: String
    ): TranslationCallPlan {
        return (
            TranslationCallRoutePolicy.plan(region, number, dialCode, preferences)
                as TranslationCallPlanResult.Ready
            ).plan
    }

    private fun china() = TranslationRegionState.Resolved(
        countryIso = "CN",
        source = TranslationRegionSource.LiveLocation,
        sampledAtMs = 1L
    )

    private fun overseas(countryIso: String) = TranslationRegionState.Resolved(
        countryIso = countryIso,
        source = TranslationRegionSource.TrustedCache,
        sampledAtMs = 2L
    )
}
