package com.vvtech.aiassistant.features.assistant

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CallMonitorAudioRouteTest {
    @Test
    fun hangupIconUsesUnclippedDemoCallEndVector() {
        val icon = File("src/main/res/drawable/ic_agent_call_hangup.xml")
            .readText(Charsets.UTF_8)

        assertTrue(icon.contains("M12,9c-1.6,0"))
        assertFalse(icon.contains("android:rotation"))
        assertFalse(icon.contains("M13.832,16.568"))
    }

    @Test
    fun defaultRouteIsEarpieceAndBluetoothOnlyAppearsWhenAvailable() {
        assertEquals(
            CallMonitorAudioRoute.Earpiece,
            CallMonitorAudioRouteState().selected
        )
        assertEquals(
            listOf(CallMonitorAudioRoute.Earpiece, CallMonitorAudioRoute.Speaker),
            availableCallMonitorAudioRoutes(bluetoothAvailable = false)
        )
        assertEquals(
            listOf(
                CallMonitorAudioRoute.Earpiece,
                CallMonitorAudioRoute.Speaker,
                CallMonitorAudioRoute.Bluetooth
            ),
            availableCallMonitorAudioRoutes(bluetoothAvailable = true)
        )
    }

    @Test
    fun audioSourceCanOnlyBeChangedWhileMonitoring() {
        assertTrue(CallMonitorPlaybackState.Playing.allowsAudioRouteSelection())
        assertFalse(CallMonitorPlaybackState.Off.allowsAudioRouteSelection())
        assertFalse(CallMonitorPlaybackState.Connecting.allowsAudioRouteSelection())
        assertFalse(CallMonitorPlaybackState.Muted.allowsAudioRouteSelection())
        assertFalse(CallMonitorPlaybackState.Reconnecting.allowsAudioRouteSelection())
        assertFalse(CallMonitorPlaybackState.Failed.allowsAudioRouteSelection())
    }
}
