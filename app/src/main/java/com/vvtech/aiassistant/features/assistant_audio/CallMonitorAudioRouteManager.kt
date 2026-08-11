package com.vvtech.aiassistant.features.assistant_audio

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRoute
import com.vvtech.aiassistant.features.assistant.CallMonitorAudioRouteState

internal class CallMonitorAudioRouteManager(
    context: Context,
    private val onRouteStateChanged: (CallMonitorAudioRouteState, String) -> Unit
) {
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var selectedRoute = CallMonitorAudioRoute.Earpiece
    private var active = false
    private var callbackRegistered = false
    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
            refreshDevices("device_added")
        }

        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
            refreshDevices("device_removed")
        }
    }

    fun start(initialRoute: CallMonitorAudioRoute) {
        active = true
        selectedRoute = initialRoute
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        registerDeviceCallback()
        if (!applyRoute(initialRoute)) {
            selectedRoute = CallMonitorAudioRoute.Earpiece
            applyRoute(selectedRoute)
        }
        dispatch("monitor_started")
    }

    fun select(route: CallMonitorAudioRoute) {
        if (!active) {
            return
        }
        if (route == CallMonitorAudioRoute.Bluetooth && !isBluetoothAvailable()) {
            dispatch("bluetooth_unavailable")
            return
        }
        if (applyRoute(route)) {
            selectedRoute = route
            dispatch("user_selected")
        } else {
            dispatch("route_apply_failed")
        }
    }

    fun stop() {
        active = false
        unregisterDeviceCallback()
        clearRoute()
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    private fun registerDeviceCallback() {
        if (callbackRegistered) {
            return
        }
        audioManager.registerAudioDeviceCallback(
            deviceCallback,
            Handler(Looper.getMainLooper())
        )
        callbackRegistered = true
    }

    private fun unregisterDeviceCallback() {
        if (!callbackRegistered) {
            return
        }
        runCatching { audioManager.unregisterAudioDeviceCallback(deviceCallback) }
        callbackRegistered = false
    }

    private fun refreshDevices(reason: String) {
        if (!active) {
            return
        }
        if (selectedRoute == CallMonitorAudioRoute.Bluetooth && !isBluetoothAvailable()) {
            selectedRoute = CallMonitorAudioRoute.Earpiece
            applyRoute(selectedRoute)
            dispatch("bluetooth_disconnected_fallback_earpiece")
            return
        }
        dispatch(reason)
    }

    private fun dispatch(reason: String) {
        onRouteStateChanged(
            CallMonitorAudioRouteState(
                selected = selectedRoute,
                bluetoothAvailable = isBluetoothAvailable()
            ),
            reason
        )
    }

    private fun applyRoute(route: CallMonitorAudioRoute): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val device = audioManager.availableCommunicationDevices.firstOrNull {
                it.matches(route)
            } ?: return false
            audioManager.setCommunicationDevice(device)
        } else {
            applyLegacyRoute(route)
        }
    }

    @Suppress("DEPRECATION")
    private fun applyLegacyRoute(route: CallMonitorAudioRoute): Boolean =
        when (route) {
            CallMonitorAudioRoute.Earpiece -> {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.isSpeakerphoneOn = false
                true
            }

            CallMonitorAudioRoute.Speaker -> {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.isSpeakerphoneOn = true
                true
            }

            CallMonitorAudioRoute.Bluetooth -> {
                if (!isBluetoothAvailable()) {
                    false
                } else {
                    audioManager.isSpeakerphoneOn = false
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                    true
                }
            }
        }

    private fun isBluetoothAvailable(): Boolean {
        val devices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
        }
        return devices.any(AudioDeviceInfo::isBluetoothCommunicationDevice)
    }

    @Suppress("DEPRECATION")
    private fun clearRoute() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        } else {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
            audioManager.isSpeakerphoneOn = false
        }
    }
}

private fun AudioDeviceInfo.matches(route: CallMonitorAudioRoute): Boolean =
    when (route) {
        CallMonitorAudioRoute.Earpiece -> type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
        CallMonitorAudioRoute.Speaker -> type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        CallMonitorAudioRoute.Bluetooth -> isBluetoothCommunicationDevice()
    }

private fun AudioDeviceInfo.isBluetoothCommunicationDevice(): Boolean =
    when (type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_HEARING_AID -> true

        else -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            (type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                type == AudioDeviceInfo.TYPE_BLE_SPEAKER)
    }
