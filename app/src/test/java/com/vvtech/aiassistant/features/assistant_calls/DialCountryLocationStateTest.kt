package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.domain.translation.TranslationRegionSource
import com.vvtech.aiassistant.domain.translation.TranslationRegionState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DialCountryLocationStateTest {
    @Test
    fun `permanently denied permission retry opens app settings`() {
        assertEquals(
            DialCountryLocationPermissionAction.OPEN_SETTINGS,
            dialCountryLocationPermissionAction(
                hasPermission = false,
                permissionRequested = true,
                canRequestAgain = false
            )
        )
    }

    @Test
    fun `first permission request still launches when rationale is false`() {
        assertEquals(
            DialCountryLocationPermissionAction.REQUEST_PERMISSION,
            dialCountryLocationPermissionAction(
                hasPermission = false,
                permissionRequested = false,
                canRequestAgain = false
            )
        )
    }

    @Test
    fun `granted permission retry locates without requesting permission again`() {
        assertEquals(
            DialCountryLocationPermissionAction.LOCATE,
            dialCountryLocationPermissionAction(
                hasPermission = true,
                permissionRequested = true,
                canRequestAgain = false
            )
        )
    }

    @Test
    fun `blocked permission state exposes settings action`() {
        val state = dialCountryLocationState(
            TranslationRegionState.Unavailable("未获得定位权限"),
            transientStatus = DialCountryLocationStatus.BLOCKED
        )

        assertEquals("前往设置", state.actionLabel)
    }

    @Test
    fun `trusted china cache maps to supported dial country`() {
        val state = dialCountryLocationState(
            resolved("CN", TranslationRegionSource.TrustedCache)
        )

        assertEquals(DialCountryLocationStatus.SUCCESS, state.status)
        assertEquals("+86", state.country?.dialCode)
    }

    @Test
    fun `unsupported overseas country does not corrupt trusted routing region`() {
        val state = dialCountryLocationState(
            resolved("FR", TranslationRegionSource.LiveLocation)
        )

        assertEquals(DialCountryLocationStatus.UNSUPPORTED, state.status)
        assertNull(state.country)
    }

    @Test
    fun `permission denial overrides cached display while permission request resolves`() {
        val state = dialCountryLocationState(
            resolved("US", TranslationRegionSource.TrustedCache),
            transientStatus = DialCountryLocationStatus.DENIED
        )

        assertEquals(DialCountryLocationStatus.DENIED, state.status)
        assertNull(state.country)
    }

    @Test
    fun `initial unavailable state maps to idle request`() {
        val state = dialCountryLocationState(
            TranslationRegionState.Unavailable("尚未获取可信位置")
        )

        assertEquals(DialCountryLocationStatus.IDLE, state.status)
        assertEquals("点击获取当前位置", state.message)
    }

    @Test
    fun `refresh failure maps to retryable failure`() {
        val state = dialCountryLocationState(
            TranslationRegionState.Unavailable("无法确定当前位置，请授权定位后重试")
        )

        assertEquals(DialCountryLocationStatus.FAILED, state.status)
    }

    private fun resolved(
        countryIso: String,
        source: TranslationRegionSource
    ) = TranslationRegionState.Resolved(
        countryIso = countryIso,
        source = source,
        sampledAtMs = 1L
    )
}
