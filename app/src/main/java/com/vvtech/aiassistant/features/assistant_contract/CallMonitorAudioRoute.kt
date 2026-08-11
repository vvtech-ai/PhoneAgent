package com.vvtech.aiassistant.features.assistant

enum class CallMonitorAudioRoute {
    Earpiece,
    Speaker,
    Bluetooth
}

data class CallMonitorAudioRouteState(
    val selected: CallMonitorAudioRoute = CallMonitorAudioRoute.Earpiece,
    val bluetoothAvailable: Boolean = false
)

internal fun availableCallMonitorAudioRoutes(
    bluetoothAvailable: Boolean
): List<CallMonitorAudioRoute> = buildList {
    add(CallMonitorAudioRoute.Earpiece)
    add(CallMonitorAudioRoute.Speaker)
    if (bluetoothAvailable) {
        add(CallMonitorAudioRoute.Bluetooth)
    }
}

internal fun CallMonitorPlaybackState.allowsAudioRouteSelection(): Boolean =
    this == CallMonitorPlaybackState.Playing
